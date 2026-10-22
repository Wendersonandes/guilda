require "test_helper"

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
class ContactTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob = users(:bob)
    @sender = create_profile_for(@alice)
    @receiver = create_profile_for(@bob)
  end

  test "validates uniqueness of sender+receiver pair" do
    Contact.create!(sender: @sender, receiver: @receiver)
    duplicate = Contact.new(sender: @sender, receiver: @receiver)

    assert_not duplicate.valid?
  end

  test "#established? true when ties_count > 0" do
    contact = Contact.create!(sender: @sender, receiver: @receiver)
    assert_not contact.established?

    Tie.create!(contact: contact, relation: Relation::Public.instance)
    assert contact.reload.established?
  end

  test "auto-links inverse contact after create" do
    contact = Contact.create!(sender: @sender, receiver: @receiver)
    inverse = Contact.create!(sender: @receiver, receiver: @sender)

    assert_equal inverse.id, contact.reload.inverse_id
    assert_equal contact.id, inverse.reload.inverse_id
  end

  test "mutual connection is detected when both directions have ties" do
    @sender.connect_to(@receiver, as: :follower)
    contact = @sender.contact_to(@receiver)

    assert_not contact.mutual?
    assert_not @sender.mutual_with?(@receiver)
    assert @receiver.followed_by?(@sender)
    assert_not @sender.followed_by?(@receiver)
    assert_equal 0, Contact.mutual.count

    @receiver.connect_to(@sender, as: :follower)

    assert contact.reload.mutual?
    assert @sender.mutual_with?(@receiver)
    assert @receiver.mutual_with?(@sender)
    assert_equal 2, Contact.mutual.count
  end
end
