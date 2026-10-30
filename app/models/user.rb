# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  provider               :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  uid                    :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  current_profile_id     :bigint
#
# Indexes
#
#  index_users_on_current_profile_id    (current_profile_id)
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_provider_and_uid      (provider,uid) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (current_profile_id => actors.id) ON DELETE => nullify
#

# A {User} is the authentication identity of a person, managed by
# {https://github.com/heartcombo/devise Devise}. It is deliberately kept separate from the
# social graph: a user does not participate in the network directly but *through* a {Profile}.
#
# A user {#profiles has_many} profiles and points to a {#current_profile} — the {Actor} it is
# currently acting as. This is the entity recorded as the +user_author+ of an {Activity}: even
# when acting on behalf of a {Group}, the user_author still identifies the logged-in user.
#
# @see Profile The individual actor a user acts as.
# @see Actor   The social-graph node behind a profile.
class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  def self.from_omniauth(auth)
    return nil if auth.blank? || auth.info.blank?

    user = find_by(provider: auth.provider, uid: auth.uid.to_s)
    if user.nil? && auth.info.email.present?
      user = find_by("LOWER(email) = ?", auth.info.email.downcase)
      user&.update(provider: auth.provider, uid: auth.uid.to_s)
    end

    if user.nil?
      candidate_name = auth.info.name.presence || auth.info.email.to_s.split("@").first.presence || "Membro"
      user = create do |u|
        u.email = auth.info.email
        u.password = Devise.friendly_token[0, 20]
        u.provider = auth.provider
        u.uid = auth.uid.to_s
        u.profile_name = candidate_name
      end
    end

    if user&.persisted? && auth.info.image.present? && user.current_profile && !user.current_profile.avatar.attached?
      begin
        require "open-uri"
        downloaded_image = URI.parse(auth.info.image).open(read_timeout: 3, open_timeout: 2)
        user.current_profile.avatar.attach(io: downloaded_image, filename: "avatar.jpg", content_type: "image/jpeg")
      rescue StandardError => e
        Rails.logger.warn("Could not attach Google avatar: #{e.message}")
      end
    end

    user
  end

  has_many :profiles, dependent: :destroy
  belongs_to :current_profile, class_name: "Actor", optional: true
  has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"

  pay_customer default_payment_processor: :stripe

  delegate :subscribed?, :subscription, to: :payment_processor, allow_nil: true

  attr_accessor :profile_name

  # Name used by Pay to sync customer name with payment processors (e.g., Stripe)
  def pay_customer_name
    current_profile&.name.presence || email
  end

  # Synchronizes the "Professional" role and permissions on the current profile
  # based on whether the user has an active or trialing subscription.
  def sync_professional_role!
    UserSubscriptionRoleSyncService.new(self).call
  end

  # Role and permission delegators to the current profile actor
  def add_role(role, other)
    current_profile&.add_role(role, other)
  end

  def remove_role(role, other)
    current_profile&.remove_role(role, other)
  end

  def has_role?(role, other)
    current_profile ? current_profile.has_role?(role, other) : false
  end

  # Whether the current profile is allowed to perform +action+ on +object+ within +context+.
  def can?(action, object = nil, context = Site.instance)
    current_profile ? current_profile.can?(action, object, context) : false
  end
  alias_method :has_permission?, :can?

  # Whether the user can authenticate. Banned users have no site activity read permissions.
  def active_for_authentication?
    super && (current_profile.nil? || current_profile.can?(:read, :activity, Site.instance))
  end

  def inactive_message
    (current_profile && !current_profile.can?(:read, :activity, Site.instance)) ? :banned : super
  end

  validates :email, presence: true, uniqueness: true
  validates :profile_name, presence: true, on: :create

  after_create :setup_initial_profile!

  private

  # +after_create+ callback: builds the user's first {Profile} (via {ProfileCreation}) and sets
  # it as the {#current_profile}. Rolls back registration if the profile cannot be created.
  def setup_initial_profile!
    actor = ProfileCreation.new(self, name: profile_name).call
    update_column(:current_profile_id, actor.id)
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, "Profile creation failed: #{e.message}")
    raise
  end
end
