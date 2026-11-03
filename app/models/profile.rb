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
  has_many :projects, dependent: :destroy, inverse_of: :profile
  belongs_to :user

  enum :availability, { full_time: 0, freelance: 1, unavailable: 2 }

  # Profiles that have completed their wizard and have permission to publish their profile
  # on the Site (e.g. professional or tester role), making them visible in directory listings.
  scope :listed_in_directory, -> {
    site_actor_id = Site.instance.actor&.id
    publish_perm_ids = Permission.where(action: :publish, object: :profile).select(:id)
    allowed_rel_ids = RelationPermission.where(permission_id: publish_perm_ids).select(:relation_id)
    tied_actor_ids = Tie.joins(:contact)
                        .where(contacts: { sender_id: site_actor_id }, relation_id: allowed_rel_ids)
                        .select("contacts.receiver_id")

    where(wizard_complete: true)
      .where(id: Actor.where(id: tied_actor_ids, actorable_type: "Profile").select(:actorable_id))
  }

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
    location: [ :country, :state, :city ],
    occupation: [ :occupation_list ]
  }.freeze

  validates :country, :state, :city, presence: true, if: -> { required_for_step?(:location) }
  validate :occupations_limit
  validate :occupations_presence, if: -> { required_for_step?(:occupation) }

  acts_as_taggable_on :occupations

  OCCUPATIONS = YAML.load_file(Rails.root.join("config", "occupations.yml"))["occupations"].freeze

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

  def contractor?
    wizard_complete? && occupation_list.empty?
  end

  def onboarding_checklist_for(role = nil)
    target_role = (role || (contractor? ? :contractor : :professional)).to_sym
    url_helpers = Rails.application.routes.url_helpers
    actor_record = actor

    has_location = country.present? && state.present? && city.present?
    has_avatar = actor_record ? actor_record.avatar.attached? : false
    has_description = actor_record&.description.present?
    has_occupations = occupation_list.any?
    has_bio_and_occupations = has_description && has_occupations
    has_project = projects.exists?
    has_contact = mobile.present? || instagram.present? || website.present?
    has_availability = availability.present?
    has_followed = actor_record ? actor_record.sent_contacts.active.exists? : false

    if target_role == :contractor
      sections = [
        {
          id: :basic_info,
          heading: "Informações básicas do perfil",
          steps: [
            {
              id: :location,
              title: "Localização configurada",
              description: [ city, state ].reject(&:blank?).join(", ").presence || "Defina sua cidade e estado",
              completed: has_location,
              url: url_helpers.edit_my_profile_path(anchor: "section-location"),
              action_label: "Definir local"
            },
            {
              id: :avatar,
              title: "Adicionar foto ou logo",
              description: "Identifique seu perfil ou sua produtora",
              completed: has_avatar,
              url: url_helpers.edit_my_profile_path(anchor: "section-basic-info"),
              action_label: "Adicionar foto"
            },
            {
              id: :presentation,
              title: "Apresentação da contratante",
              description: "Descreva os projetos ou produções que você realiza",
              completed: has_description,
              url: url_helpers.edit_my_profile_path(anchor: "section-basic-info"),
              action_label: "Editar bio"
            },
            {
              id: :follow_connections,
              title: "Conectar com profissionais",
              description: "Acompanhe profissionais de confiança para suas produções",
              completed: has_followed,
              url: url_helpers.profiles_path,
              action_label: "Buscar no catálogo"
            }
          ]
        }
      ]
      all_steps = sections.flat_map { |s| s[:steps] }
      completed_count = all_steps.count { |s| s[:completed] }
      total_count = all_steps.size
      {
        role: :contractor,
        subtitle: "Conclua a lista de verificação para facilitar a busca e o contato com profissionais.",
        completed_count: completed_count,
        total_count: total_count,
        percentage: total_count.positive? ? ((completed_count.to_f / total_count) * 100).round : 100,
        sections: sections,
        steps: all_steps
      }
    else
      sections = [
        {
          id: :basic_info,
          heading: "Informações básicas do perfil",
          steps: [
            {
              id: :avatar,
              title: "Adicionar foto de perfil",
              description: "Perfis com foto transmitem maior confiança na contratação",
              completed: has_avatar,
              url: url_helpers.edit_my_profile_path(anchor: "section-basic-info"),
              action_label: "Adicionar foto"
            },
            {
              id: :presentation,
              title: "Preencher bio e áreas de atuação",
              description: "Apresente sua trajetória e até 3 especialidades técnicas",
              completed: has_bio_and_occupations,
              url: url_helpers.edit_my_profile_path(anchor: has_occupations ? "section-basic-info" : "section-occupations"),
              action_label: "Completar perfil"
            },
            {
              id: :first_project,
              title: "Criar seu primeiro projeto",
              description: "Apresente entregas e trabalhos técnicos realizados",
              completed: has_project,
              url: url_helpers.new_my_project_path,
              action_label: "Publicar projeto"
            }
          ]
        },
        {
          id: :how_to_be_hired,
          heading: "Como ser contratado",
          steps: [
            {
              id: :contact_channels,
              title: "Adicionar WhatsApp ou site",
              description: "Permita que contratantes falem direto com você",
              completed: has_contact,
              url: url_helpers.edit_my_profile_path(anchor: "section-contact"),
              action_label: "Adicionar contato"
            },
            {
              id: :availability,
              title: "Definir sua disponibilidade",
              description: "Informe se está disponível para freelances ou projetos",
              completed: has_availability,
              url: url_helpers.edit_my_profile_path(anchor: "section-availability"),
              action_label: "Definir status"
            }
          ]
        }
      ]
      all_steps = sections.flat_map { |s| s[:steps] }
      completed_count = all_steps.count { |s| s[:completed] }
      total_count = all_steps.size
      {
        role: :professional,
        subtitle: "Conclua a lista de verificação para aumentar a visibilidade do seu perfil na Guilda.",
        completed_count: completed_count,
        total_count: total_count,
        percentage: total_count.positive? ? ((completed_count.to_f / total_count) * 100).round : 100,
        sections: sections,
        steps: all_steps
      }
    end
  end

  def onboarding_steps(role = nil)
    onboarding_checklist_for(role)[:steps]
  end

  def onboarding_completed?(role = nil)
    return true unless wizard_complete?
    onboarding_steps(role).all? { |step| step[:completed] }
  end

  def onboarding_completion_percentage(role = nil)
    onboarding_checklist_for(role)[:percentage]
  end

  def self.ransackable_attributes(auth_object = nil)
    [ "city", "state" ]
  end

  def self.ransackable_associations(auth_object = nil)
    [ "actor" ]
  end

  private

  # Normalizes the contact fields before validation:
  # * +mobile+ is stored as digits only (e.g. "11987654321"), dropping an optional "55" country
  #   code when present.
  # * +instagram+ is stored as the canonical profile URL (accepts @handle, handle or URL).
  def normalize_contact_info
    self.mobile = normalize_mobile(mobile) if mobile.present?
    self.instagram = normalize_instagram(instagram) if instagram.present?
  end

  def normalize_mobile(value)
    digits = value.to_s.gsub(/\D/, "")
    digits = digits.delete_prefix("55") if digits.length == 13 && digits.start_with?("55")
    digits
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
