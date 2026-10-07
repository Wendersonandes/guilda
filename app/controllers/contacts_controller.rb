# Manages the current actor's {Contact Contacts} (its social connections). Creating a contact
# establishes a {Tie} through {Actor#connect_to}.
#
# @see ContactPolicy
# @see Actor#connect_to
class ContactsController < ApplicationController
  include FeatureGated

  feature_gated_by :contacts

  # Lists the current actor's established contacts (scoped via +ContactPolicy::Scope+) plus the
  # pending incoming requests from other profiles.
  def index
    authorize Contact
    @contacts_base = policy_scope(Contact)
                       .joins(:ties)
                       .where(sender_id: current_actor.id)
                       .joins(:receiver)
                       .merge(Actor.where(actorable_type: "Profile"))
                       .joins("INNER JOIN profiles ON profiles.id = actors.actorable_id AND actors.actorable_type = 'Profile'")
                       .preload(receiver: { actorable: :occupations })
                       .distinct

    @cities = @contacts_base.pluck("profiles.city").uniq.compact.sort
    @occupations = Profile::OCCUPATIONS.map { |o| o["name"] }

    @contacts = @contacts_base

    if params[:city].present?
      @contacts = @contacts.where(profiles: { city: params[:city] })
    end

    if params[:occupation].present?
      @contacts = @contacts.joins("INNER JOIN taggings ON taggings.taggable_id = profiles.id AND taggings.taggable_type = 'Profile' AND taggings.context = 'occupations'")
                           .joins("INNER JOIN tags ON tags.id = taggings.tag_id")
                           .where(tags: { name: params[:occupation] })
    end

    @pagy, @contacts = pagy(@contacts)
  end

  # Returns the pending incoming contact requests to be rendered inside the right sidebar.
  def pending
    authorize Contact, :index?
    @pending = Contact.pending
                      .where(receiver_id: current_actor.id)
                      .joins(:sender)
                      .merge(Actor.where(actorable_type: "Profile"))
                      .includes(:sender)
    render layout: false
  end

  # Connects the current actor to another actor using the relation named by +params[:as]+
  # (defaults to +:friend+). Authorized via +ContactPolicy#create?+.
  #
  # @note Responds via Turbo Stream to update the contact UI without a page reload.
  def create
    @other = Actor.find_by!(slug: params[:actor_id])
    authorize Contact.new(sender: current_actor, receiver: @other)

    # Preload relations on current_actor for connect_to
    ActiveRecord::Associations::Preloader.new(records: [current_actor], associations: :relations).call

    current_actor.connect_to(@other, as: params[:as] || :friend)
    respond_to do |format|
      format.turbo_stream do
        if request.referer&.include?(contacts_path)
          redirect_to contacts_path, status: :see_other
        end
      end
      format.html { redirect_to request.referer || contacts_path, notice: "Contact added as #{params[:as] || :friend}." }
    end
  end

  # Removes a contact (authorized via +ContactPolicy#destroy?+).
  #
  # @note Responds via Turbo Stream to remove the contact from the list.
  def destroy
    @contact = Contact.find_by!(id: params[:id])
    authorize @contact
    @other = @contact.receiver_id == current_actor.id ? @contact.sender : @contact.receiver
    @contact.destroy
    respond_to do |format|
      format.turbo_stream do
        if request.referer&.include?(contacts_path)
          redirect_to contacts_path, status: :see_other
        end
      end
      format.html { redirect_to request.referer || contacts_path, notice: "Contact removed." }
    end
  end
end
