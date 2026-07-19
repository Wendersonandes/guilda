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
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  sign_in_count          :integer          default(0), not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  current_profile_id     :bigint
#
# Indexes
#
#  index_users_on_current_profile_id    (current_profile_id)
#  index_users_on_email                 (email) UNIQUE
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
         :recoverable, :rememberable, :validatable, :trackable

  has_many :profiles, dependent: :destroy
  belongs_to :current_profile, class_name: "Actor", optional: true
  has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"

  attr_accessor :profile_name

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

  def has_permission?(action, object, context = Site.instance)
    current_profile ? current_profile.has_permission?(action, object, context) : false
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
