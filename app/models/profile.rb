# == Schema Information
#
# Table name: profiles
#
#  id              :bigint           not null, primary key
#  address         :string
#  availability    :integer
#  birthday        :date
#  city            :string
#  country         :string
#  instagram       :string
#  mobile          :string
#  organization    :string
#  phone           :string
#  state           :string
#  website         :string
#  wizard_complete :boolean          default(FALSE), not null
#  zipcode         :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null
#
# Indexes
#
#  index_profiles_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id) ON DELETE => restrict
#

# A {Profile} is the *individual* actor subtype: the persona a {User} presents in the social
# network. It is one of the concrete types behind {Actor}'s +delegated_type :actorable+
# (alongside {Group} and {Site}).
#
# The profile holds personal contact fields (address, phone, website, etc.) and delegates the
# shared identity attributes (name, email, slug, description) to its {#actor}. It is also
# backed by an {ActivityObject}, so a profile can be followed and acted upon.
#
# @see User   The authentication identity that owns this profile.
# @see Actor  The social-graph node this profile delegates to.
class Profile < ApplicationRecord
  has_one :actor, as: :actorable, dependent: :destroy, autosave: true
  has_one :activity_object, as: :objectable, dependent: :destroy, autosave: true
  belongs_to :user

  enum :availability, { full_time: 0, freelance: 1, unavailable: 2 }

  AVAILABILITY_OPTIONS = {
    "full_time" => "Tempo integral",
    "freelance" => "Freelance",
    "unavailable" => "Indisponível"
  }.freeze

  # Availability options offered in the directory filter (excludes "unavailable", so the
  # search stays focused on professionals accepting work).
  FILTERABLE_AVAILABILITY_OPTIONS = AVAILABILITY_OPTIONS.except("unavailable").freeze

  # Brazilian mobile: 2-digit area code + 9 digits (starting with 9).
  BR_MOBILE_REGEX = /\A[1-9]{2}9[0-9]{8}\z/
  # Instagram handle (without the leading @ or URL).
  INSTAGRAM_HANDLE_REGEX = /\A[A-Za-z0-9._]{1,30}\z/
  INSTAGRAM_BASE_URL = "https://instagram.com"

  before_validation :normalize_contact_info

  def availability_label
    AVAILABILITY_OPTIONS[availability]
  end

  delegate :name, :name=, :email, :email=, :slug, :description, :description=,
           :notification_settings, :activity_object_id,
           to: :actor, allow_nil: true

  accepts_nested_attributes_for :actor, update_only: true
  attr_accessor :form_step

  validates :user, presence: true
  validate :mobile_format, if: -> { mobile.present? }
  validate :instagram_format, if: -> { instagram.present? }

  FORM_STEPS = {
    location: [:country, :state, :city],
    occupation: [:occupation_list]
  }.freeze

  validates :country, :state, :city, presence: true, if: -> { required_for_step?(:location) }
  validate :occupations_limit
  validate :occupations_presence, if: -> { required_for_step?(:occupation) }

  acts_as_taggable_on :occupations

  OCCUPATIONS = YAML.load_file(Rails.root.join('config', 'occupations.yml'))['occupations'].freeze

  def required_for_step?(step)
    # Full-model validation when form_step is nil (e.g. after wizard is complete)
    # Note: we use wizard_complete? to determine if we should validate everything
    return true if wizard_complete?
    return false if form_step.nil? # allows ProfileCreation to make a blank profile

    step_keys = self.class::FORM_STEPS.keys
    step_keys.index(form_step.to_sym) >= step_keys.index(step.to_sym)
  end

  def current_step
    if country.blank? || state.blank? || city.blank?
      :location
    else
      :occupation
    end
  end

  def allowed_step?(step_name)
    return true if step_name.to_sym == :location
    if step_name.to_sym == :occupation
      country.present? && state.present? && city.present?
    else
      false
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    ["city", "state"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["actor"]
  end

  private

  # Normalizes the contact fields before validation:
  # * +mobile+ is stored as digits only (e.g. "11987654321").
  # * +instagram+ is stored as the canonical profile URL (accepts @handle, handle or URL).
  def normalize_contact_info
    self.mobile = mobile.to_s.gsub(/\D/, "") if mobile.present?
    self.instagram = normalize_instagram(instagram) if instagram.present?
  end

  def normalize_instagram(value)
    handle = value.to_s.strip
    handle = handle.sub(%r{\Ahttps?://(www\.)?instagram\.com/}i, "")
    handle = handle.sub(%r{\A(www\.)?instagram\.com/}i, "")
    handle = handle.delete_prefix("@").split(%r{[/?#]}).first.to_s
    handle.present? ? "#{INSTAGRAM_BASE_URL}/#{handle}" : nil
  end

  def mobile_format
    errors.add(:mobile, "deve estar no formato (DDD) 9XXXX-XXXX") unless mobile.match?(BR_MOBILE_REGEX)
  end

  def instagram_format
    handle = instagram.sub("#{INSTAGRAM_BASE_URL}/", "")
    errors.add(:instagram, "é inválido") unless handle.match?(INSTAGRAM_HANDLE_REGEX)
  end

  def occupations_limit
    if occupation_list.size > 3
      errors.add(:occupation_list, "não pode ter mais do que 3 categorias")
    end
  end

  def occupations_presence
    if occupation_list.empty?
      errors.add(:occupation_list, "selecione pelo menos 1 categoria")
    end
  end


end
