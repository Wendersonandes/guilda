require "test_helper"

class GroupMembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob = users(:bob)
    @carol_user = User.create!(email: "carol@example.com", password: "password123", profile_name: "Carol")
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor = create_profile_for(@bob, name: "Bob")
    @carol_actor = @carol_user.current_profile
    @alice.update!(current_profile: @alice_actor)
    @bob.update!(current_profile: @bob_actor)
    @group = create_group_with_admin(@alice_actor)
  end

  test "should get index" do
    get group_memberships_path(@group)
    assert_response :success
  end

  test "admin can add member" do
    sign_in @alice
    assert_difference "Tie.count", 1 do
      post group_memberships_path(@group), params: { actor_id: @bob_actor.id, role: "member" }
    end
    assert_redirected_to group_memberships_path(@group)
    assert @group.actor.has_relation_with?(@bob_actor, "Member")
  end

  test "non-admin cannot add member" do
    sign_in @bob
    assert_no_difference "Tie.count" do
      post group_memberships_path(@group), params: { actor_id: @carol_actor.id, role: "member" }
    end
    assert_response :redirect
    assert_not @group.actor.has_relation_with?(@carol_actor, "Member")
  end

  test "admin can change member role" do
    sign_in @alice
    @group.actor.connect_to(@bob_actor, as: "member")

    patch group_membership_path(@group, @bob_actor), params: { from_role: "member", to_role: "moderator" }
    assert_redirected_to group_memberships_path(@group)
    assert @group.actor.has_relation_with?(@bob_actor, "Moderator")
    assert_not @group.actor.has_relation_with?(@bob_actor, "Member")
  end

  test "non-admin cannot change role" do
    sign_in @bob
    @group.actor.connect_to(@bob_actor, as: "member")

    patch group_membership_path(@group, @bob_actor), params: { from_role: "member", to_role: "moderator" }
    assert_response :redirect
    assert_not @group.actor.has_relation_with?(@bob_actor, "Moderator")
    assert @group.actor.has_relation_with?(@bob_actor, "Member")
  end

  test "admin can remove member" do
    sign_in @alice
    @group.actor.connect_to(@bob_actor, as: "member")

    assert_difference "Tie.count", -1 do
      delete group_membership_path(@group, @bob_actor), params: { role: "member" }
    end
    assert_redirected_to group_memberships_path(@group)
    assert_not @group.actor.has_relation_with?(@bob_actor, "Member")
  end

  test "member can leave group" do
    sign_in @bob
    @group.actor.connect_to(@bob_actor, as: "member")

    assert_difference "Tie.count", -1 do
      delete group_membership_path(@group, @bob_actor), params: { role: "member" }
    end
    assert_redirected_to groups_path
    assert_not @group.actor.has_relation_with?(@bob_actor, "Member")
  end

  test "non-member cannot leave group" do
    sign_in @bob

    assert_no_difference "Tie.count" do
      delete group_membership_path(@group, @bob_actor), params: { role: "member" }
    end
    assert_response :redirect
  end

  test "admin can see insights" do
    sign_in @alice
    get insights_group_memberships_path(@group)
    assert_response :success
  end

  test "non-admin cannot see insights" do
    sign_in @bob
    get insights_group_memberships_path(@group)
    assert_response :redirect
  end

  test "insights shows stats for group activity" do
    sign_in @alice
    @group.actor.connect_to(@bob_actor, as: "member")
    create_post(author: @bob_actor, owner: @group.actor, title: "Test", body: "Post content")

    get insights_group_memberships_path(@group)
    assert_response :success
    assert_select "p.text-3xl.font-bold.text-green-700", text: "1"
  end

  test "self-join public group creates bidirectional ties" do
    @group.update!(privacy: :public_group)
    sign_in @bob

    assert_difference "Tie.count", 2 do
      post group_memberships_path(@group), params: { actor_id: @bob_actor.id }
    end
    assert_redirected_to group_memberships_path(@group)
    assert @group.actor.has_relation_with?(@bob_actor, "Member")
    assert @bob_actor.has_relation_with?(@group.actor, "follow")
  end

  test "self-join private group creates pending request" do
    @group.update!(privacy: :private_group)
    sign_in @bob

    assert_difference "Tie.count", 1 do
      post group_memberships_path(@group), params: { actor_id: @bob_actor.id }
    end
    assert_redirected_to group_memberships_path(@group)
    assert_not @group.actor.has_relation_with?(@bob_actor, "Member")
    assert @bob_actor.has_relation_with?(@group.actor, "follow")
  end

  test "admin can approve pending request" do
    @group.update!(privacy: :private_group)
    sign_in @bob
    post group_memberships_path(@group), params: { actor_id: @bob_actor.id }

    request_contact = @group.actor.received_contacts.pending.first
    assert request_contact.present?

    sign_in @alice
    post approve_request_group_memberships_path(@group), params: { contact_id: request_contact.id, role: "moderator" }
    assert_redirected_to group_memberships_path(@group)
    assert @group.actor.has_relation_with?(@bob_actor, "Moderator")
  end

  test "admin can reject pending request" do
    @group.update!(privacy: :private_group)
    sign_in @bob
    post group_memberships_path(@group), params: { actor_id: @bob_actor.id }

    request_contact = @group.actor.received_contacts.pending.first

    sign_in @alice
    assert_difference "Contact.count", -1 do
      post reject_request_group_memberships_path(@group), params: { contact_id: request_contact.id }
    end
    assert_redirected_to group_memberships_path(@group)
  end

  test "non-admin cannot approve request" do
    @group.update!(privacy: :private_group)
    sign_in @bob
    post group_memberships_path(@group), params: { actor_id: @bob_actor.id }
    request_contact = @group.actor.received_contacts.pending.first

    post approve_request_group_memberships_path(@group), params: { contact_id: request_contact.id, role: "member" }
    assert_response :redirect
    assert_not @group.actor.has_relation_with?(@bob_actor, "Member")
  end

  test "user can accept invite" do
    sign_in @alice
    post group_memberships_path(@group), params: { actor_id: @bob_actor.id, role: "member" }
    invite_contact = @bob_actor.received_contacts.pending.first

    sign_in @bob
    post accept_invite_group_memberships_path(@group)
    assert_redirected_to group_memberships_path(@group)
    assert @bob_actor.has_relation_with?(@group.actor, "follow")
  end

  test "user can decline invite" do
    sign_in @alice
    post group_memberships_path(@group), params: { actor_id: @bob_actor.id, role: "member" }
    invite_contact = @bob_actor.received_contacts.pending.first

    sign_in @bob
    post decline_invite_group_memberships_path(@group), params: { contact_id: invite_contact.id }
    assert_redirected_to group_memberships_path(@group)
    assert_not @bob_actor.has_relation_with?(@group.actor, "follow")
  end

  test "accept_invite without pending invite redirects with alert" do
    sign_in @bob
    post accept_invite_group_memberships_path(@group)
    assert_redirected_to group_memberships_path(@group)
    assert_equal "Nenhum convite pendente encontrado.", flash[:alert]
  end

  test "duplicate self-join shows already a member notice" do
    sign_in @bob
    @group.actor.connect_to(@bob_actor, as: "member")
    post group_memberships_path(@group), params: { actor_id: @bob_actor.id }
    assert_redirected_to group_memberships_path(@group)
    assert_equal "Você já é membro.", flash[:notice]
  end

  test "duplicate private request shows already pending notice" do
    @group.update!(privacy: :private_group)
    sign_in @bob
    @bob_actor.connect_to(@group.actor, as: "follow")
    post group_memberships_path(@group), params: { actor_id: @bob_actor.id }
    assert_redirected_to group_memberships_path(@group)
    assert_equal "Sua solicitação já está pendente.", flash[:notice]
  end

  private

  def create_group_with_admin(admin_actor)
    group = Group.new
    group.build_actor(name: "Test Group Controller")
    GroupCreation.new(admin_actor, group).call
  end

  def create_post(author:, owner:, title:, body: "")
    activity = Activity.new(verb: :post, author: author, owner: owner)
    activity.user_author = author.subject.is_a?(Profile) ? author.subject.user : nil
    ActivityCreation.new(
      activity,
      text: { title: title, body: body },
      relation_ids: owner.activity_relation_ids
    ).call
  end
end
