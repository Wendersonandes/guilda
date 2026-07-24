require "test_helper"

class CommentPolicyTest < ActiveSupport::TestCase
  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob   = users(:bob)
    @alice_actor = create_profile_for(@alice, name: "Alice")
    @bob_actor   = create_profile_for(@bob, name: "Bob")

    @comment = Comment.new
    @comment.build_activity_object(
      description: "Policy comment",
      author: @alice_actor,
      owner: @alice_actor
    )
  end

  test "logged in user can create and reply to comment" do
    policy = CommentPolicy.new(@bob, @comment)
    assert policy.create?
    assert policy.reply?
    assert policy.upvote?
    assert policy.downvote?
    assert policy.flag?
  end

  test "only author can update comment" do
    policy_alice = CommentPolicy.new(@alice, @comment)
    policy_bob   = CommentPolicy.new(@bob, @comment)
    
    assert policy_alice.update?
    assert_not policy_bob.update?
  end

  test "author or owner can destroy comment" do
    policy_alice = CommentPolicy.new(@alice, @comment)
    policy_bob   = CommentPolicy.new(@bob, @comment)
    
    assert policy_alice.destroy?
    assert_not policy_bob.destroy?
  end

  test "signed out user cannot create comment" do
    policy = CommentPolicy.new(nil, @comment)
    assert_not policy.create?
    assert_not policy.reply?
  end

  test "silenced group member cannot comment on group activity" do
    group = Group.new
    group.build_actor(name: "Test Group")
    GroupCreation.new(@alice_actor, group).call
    group_actor = group.actor
    
    # Alice is the owner, she can comment
    comment_alice = Comment.new
    comment_alice.build_activity_object(
      description: "Alice comment",
      author: @alice_actor,
      owner: group_actor
    )
    assert CommentPolicy.new(@alice, comment_alice).create?

    # Connect Bob as member, he can comment
    group_actor.connect_to(@bob_actor, as: "member")
    comment_bob = Comment.new
    comment_bob.build_activity_object(
      description: "Bob comment",
      author: @bob_actor,
      owner: group_actor
    )
    @bob_actor.reload
    assert CommentPolicy.new(@bob, comment_bob).create?

    # Reconnect Bob as silenced, he cannot comment
    group_actor.disconnect_from(@bob_actor, "member")
    group_actor.connect_to(@bob_actor, as: "silenced")
    @bob_actor.reload
    
    comment_bob_silenced = Comment.new
    comment_bob_silenced.build_activity_object(
      description: "Bob silenced comment",
      author: @bob_actor,
      owner: group_actor
    )
    assert_not CommentPolicy.new(@bob, comment_bob_silenced).create?
  end
end
