# Authorization for {Contact Contacts}. Any signed-in user may list and create contacts; only
# the contact's sender may destroy it. The {Scope} limits listings to the acting actor's sent
# contacts.
#
# @see Contact
class ContactPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def create?
    user.present? && actor.present? && actor.can?(:follow, nil, Site.instance)
  end

  def destroy?
    actor && (record.sender_id == actor.id || record.receiver_id == actor.id)
  end

  class Scope < Scope
    # @return [ActiveRecord::Relation<Contact>] contacts sent by the acting actor.
    def resolve
      return scope.none unless actor
      scope.where(sender_id: actor.id)
    end
  end
end
