# == Schema Information
#
# Table name: contacts
#
#  id          :bigint           not null, primary key
#  ties_count  :integer          default(0)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  inverse_id  :bigint
#  receiver_id :bigint           not null
#  sender_id   :bigint           not null
#
# Indexes
#
#  index_contacts_on_inverse_id                 (inverse_id)
#  index_contacts_on_receiver_id                (receiver_id)
#  index_contacts_on_sender_id_and_receiver_id  (sender_id,receiver_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (inverse_id => contacts.id) ON DELETE => nullify
#  fk_rails_...  (receiver_id => actors.id) ON DELETE => restrict
#  fk_rails_...  (sender_id => actors.id) ON DELETE => restrict
#

# A {Contact} is an ordered pair of {Actor Actors}: a +sender+ and a +receiver+.
#
# A {Contact} on its own does *not* imply a real link between the two actors. It is created
# for convenience (e.g. by {Actor#suggestions}) and the actual link is stored as one or more
# {Tie Ties}. When Alice adds Bob, a {Contact} from Alice to Bob is created together with a
# {Tie} carrying the {Relation} she chose.
#
# == Inverse contacts
# The inverse of the {Contact} from Alice to Bob is the {Contact} from Bob to Alice
# (see {#inverse}). Inverse contacts let us know whether a contact has been *replied*
# (see {#replied?}), for instance when Bob adds Alice back.
#
# @see Tie      The materialized link that makes a contact active.
# @see Relation The type carried by each tie.
class Contact < ApplicationRecord
  belongs_to :inverse, class_name: "Contact", optional: true
  belongs_to :sender, class_name: "Actor", counter_cache: :sent_contacts_count
  belongs_to :receiver, class_name: "Actor"

  has_many :ties, class_name: "Tie", dependent: :destroy, inverse_of: :contact
  has_many :relations, through: :ties

  # Contacts whose sender is +a+.
  #
  # @param a [Actor, Integer] the sender (or its id).
  # @return [ActiveRecord::Relation<Contact>]
  scope :sent_by, ->(a) { where(sender_id: Actor.normalize_id(a)) }

  # Contacts whose receiver is +a+.
  #
  # @param a [Actor, Integer] the receiver (or its id).
  # @return [ActiveRecord::Relation<Contact>]
  scope :received_by, ->(a) { where(receiver_id: Actor.normalize_id(a)) }

  # Established contacts, i.e. those backed by at least one {Tie} (+ties_count > 0+).
  #
  # @return [ActiveRecord::Relation<Contact>]
  scope :active, -> { where(arel_table[:ties_count].gt(0)) }

  # Contacts linked through at least one positive {Relation} (a real, active connection).
  #
  # @return [ActiveRecord::Relation<Contact>]
  # @see Relation.positive_names
  scope :positive, -> {
    select("DISTINCT contacts.*")
      .joins(:relations)
      .merge(Relation.where(type: Relation.positive_names))
  }

  # Contacts that are not self-contacts (sender differs from receiver).
  #
  # @return [ActiveRecord::Relation<Contact>]
  scope :not_reflexive, -> { where(arel_table[:sender_id].not_eq(arel_table[:receiver_id])) }

  # Contact requests awaiting a reply: active, positive and non-reflexive contacts whose
  # {#inverse} does not exist yet or is not established.
  #
  # @return [ActiveRecord::Relation<Contact>]
  scope :pending, -> {
    active.positive.not_reflexive
         .joins("LEFT JOIN contacts AS inverse_contacts ON inverse_contacts.id = contacts.inverse_id")
         .where(arel_table[:inverse_id].eq(nil).or(Contact.arel_table.alias("inverse_contacts")[:ties_count].eq(0)))
  }

  # Contacts that are mutually connected (both sides established).
  #
  # @return [ActiveRecord::Relation<Contact>]
  scope :mutual, -> {
    active.positive.not_reflexive
          .joins("INNER JOIN contacts AS inverse_contacts ON inverse_contacts.id = contacts.inverse_id")
          .where(Contact.arel_table.alias("inverse_contacts")[:ties_count].gt(0))
  }

  validates :sender, :receiver, presence: true
  validates :sender_id, uniqueness: { scope: :receiver_id }

  after_create :link_inverse

  # Is this contact active, i.e. does it have at least one {Tie}?
  #
  # @return [Boolean]
  def established?
    ties_count.to_i > 0
  end

  # Does this contact have the same sender and receiver (a self-contact)?
  #
  # @return [Boolean]
  def reflexive?
    sender_id == receiver_id
  end

  # Is the {#inverse} contact present and established? (i.e. the other actor connected back).
  #
  # @return [Boolean]
  def replied?
    inverse_id.present? && inverse&.established?
  end
  alias_method :mutual?, :replied?

  # The {#inverse} contact, creating it (from receiver to sender) when it does not exist yet.
  #
  # @return [Contact]
  def inverse!
    inverse || receiver.contact_to!(sender)
  end

  private

  # +after_create+ callback: links this contact with its opposite-direction {Contact} through
  # the +inverse_id+ column on both records, when one already exists.
  def link_inverse
    existing = self.class.find_by(sender_id: receiver_id, receiver_id: sender_id)
    return unless existing

    update_column(:inverse_id, existing.id)
    existing.update_column(:inverse_id, id)
  end
end
