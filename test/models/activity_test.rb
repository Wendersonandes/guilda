require "test_helper"

# == Schema Information
#
# Table name: activities
#
#  id             :bigint           not null, primary key
#  verb           :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  author_id      :bigint           not null
#  owner_id       :bigint           not null
#  parent_id      :bigint
#  user_author_id :bigint
#
# Indexes
#
#  index_activities_on_author_id       (author_id)
#  index_activities_on_created_at      (created_at)
#  index_activities_on_owner_id        (owner_id)
#  index_activities_on_parent_id       (parent_id)
#  index_activities_on_user_author_id  (user_author_id)
#  index_activities_on_verb            (verb)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => actors.id) ON DELETE => restrict
#  fk_rails_...  (owner_id => actors.id) ON DELETE => restrict
#  fk_rails_...  (parent_id => activities.id) ON DELETE => nullify
#  fk_rails_...  (user_author_id => users.id) ON DELETE => restrict
#
class ActivityTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    seed_permissions_and_relations
    @alice = users(:alice)
    @bob = users(:bob)
    @author = create_profile_for(@alice)
    @owner = create_profile_for(@bob)
  end

  test "verb enum maps correctly" do
    assert_equal 0, Activity.verbs[:follow]
    assert_equal 1, Activity.verbs[:like]
    assert_equal 2, Activity.verbs[:make_friend]
    assert_equal 3, Activity.verbs[:post]
    assert_equal 4, Activity.verbs[:update]
    assert_equal 5, Activity.verbs[:join]
  end

  test "validates presence of author and owner" do
    activity = Activity.new(verb: :post)
    assert_not activity.valid?
    assert_includes activity.errors[:author], "é obrigatório(a)"
    assert_includes activity.errors[:owner], "é obrigatório(a)"
  end

  test ".roots returns activities without parent" do
    parent = Activity.create!(verb: :post, author: @author, owner: @owner,
                              relation_ids: [ Relation::Public.instance.id ])
    child = Activity.create!(verb: :like, author: @author, owner: @owner, parent: parent,
                             relation_ids: [ Relation::Public.instance.id ])

    assert_includes Activity.roots, parent
    assert_not_includes Activity.roots, child
  end

  test "#reflexive? true when author == owner" do
    activity = Activity.new(verb: :post, author: @author, owner: @author)
    assert activity.reflexive?
  end

  test "#reflexive? false when author != owner" do
    activity = Activity.new(verb: :post, author: @author, owner: @owner)
    assert_not activity.reflexive?
  end

  test "#public? true when includes Relation::Public" do
    activity = Activity.create!(verb: :post, author: @author, owner: @owner,
                                relation_ids: [ Relation::Public.instance.id ])
    assert activity.public?
  end

  test "#represented_author? true when user_author differs from author" do
    activity = Activity.create!(verb: :post, author: @author, owner: @owner,
                                user_author: @alice,
                                relation_ids: [ Relation::Public.instance.id ])
    assert activity.represented_author?
  end

  test "#children returns child activities" do
    parent = Activity.create!(verb: :post, author: @author, owner: @owner,
                              relation_ids: [ Relation::Public.instance.id ])
    child = Activity.create!(verb: :like, author: @owner, owner: @author, parent: parent,
                             relation_ids: [ Relation::Public.instance.id ])

    assert_includes parent.children, child
    assert_equal parent, child.parent
  end

  test "#liked_by? finds like child activities" do
    parent = Activity.create!(verb: :post, author: @author, owner: @owner,
                              relation_ids: [ Relation::Public.instance.id ])
    Activity.create!(verb: :like, author: @owner, owner: @author, parent: parent,
                     relation_ids: [ Relation::Public.instance.id ])

    assert parent.liked_by?(@owner)
    assert_not parent.liked_by?(@author)
  end

  test "#root returns self for root activities" do
    activity = Activity.create!(verb: :post, author: @author, owner: @owner,
                                relation_ids: [ Relation::Public.instance.id ])
    assert_equal activity, activity.root
  end

  test "new post notifies followers" do
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_notifications")
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_events")

    ActivityAction.create!(actor: @owner, activity_object: @author.activity_object, follow: true)

    activity = Activity.new(verb: :post, author: @author, owner: @author)
    perform_enqueued_jobs do
      post_activity = ActivityCreation.new(activity, text: { body: "Alice's new post" }).call
    end

    assert_equal 1, @owner.notifications.count
    notification = @owner.notifications.first
    assert_equal "PostPublishedNotifier", notification.event.class.name
    assert_equal "alice publicou um novo post.", notification.message
  end

  test "liking post notifies author" do
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_notifications")
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_events")

    activity = Activity.new(verb: :post, author: @author, owner: @author)
    post_activity = ActivityCreation.new(activity, text: { body: "Alice's new post" }).call

    perform_enqueued_jobs do
      like = Like.build(@owner, @bob, post_activity)
      like.save!
    end

    assert_equal 1, @author.notifications.count
    notification = @author.notifications.first
    assert_equal "ObjectLikedNotifier", notification.event.class.name
    assert_equal "bob curtiu sua publicação.", notification.message
  end

  test "commenting post notifies author" do
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_notifications")
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_events")

    activity = Activity.new(verb: :post, author: @author, owner: @author)
    post_activity = ActivityCreation.new(activity, text: { body: "Alice's new post" }).call

    perform_enqueued_jobs do
      comment_activity = CommentCreation.new(
        author: @owner,
        user_author: @bob,
        parent_activity: post_activity,
        text: "Nice post!"
      ).call
    end

    assert_equal 1, @author.notifications.count
    notification = @author.notifications.first
    assert_equal "ObjectCommentedNotifier", notification.event.class.name
    assert_equal "bob comentou em sua publicação.", notification.message
  end

  test "destroying activity destroys associated noticed event and notifications" do
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_notifications")
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_events")

    activity = Activity.new(verb: :post, author: @author, owner: @author)
    ActivityAction.create!(actor: @owner, activity_object: @author.activity_object, follow: true)
    post_activity = nil
    perform_enqueued_jobs do
      post_activity = ActivityCreation.new(activity, text: { body: "Alice's new post" }).call
    end

    assert_equal 1, Noticed::Event.count
    assert_equal 1, Noticed::Notification.count

    assert_difference -> { Noticed::Event.count } => -1, -> { Noticed::Notification.count } => -1 do
      post_activity.destroy!
    end
  end

  test "deleting activity before job runs prevents notification delivery" do
    # Run any setup-related queued jobs first so they are processed and cleared
    perform_enqueued_jobs

    ActiveRecord::Base.connection.execute("DELETE FROM noticed_notifications")
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_events")

    ActivityAction.create!(actor: @owner, activity_object: @author.activity_object, follow: true)
    activity = Activity.new(verb: :post, author: @author, owner: @author)
    post_activity = ActivityCreation.new(activity, text: { body: "Quickly deleted" }).call
    
    # Destroy the activity before the queued job is processed
    post_activity.destroy!

    # Execute all queued jobs (which will try to run PostPublishedNotifier job)
    perform_enqueued_jobs

    # Validation should prevent the creation of the event and notification
    assert_equal 0, Noticed::Event.count
    assert_equal 0, Noticed::Notification.count
  end

  test "new follower notification is delivered on follow and make_friend but not Site follow" do
    # Run any setup-related queued jobs first so they are processed and cleared
    perform_enqueued_jobs
    
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_notifications")
    ActiveRecord::Base.connection.execute("DELETE FROM noticed_events")

    # 1. Platform follow (Site connection)
    assert_no_difference -> { @author.notifications.count } do
      perform_enqueued_jobs do
        Activity.create!(
          verb: :follow,
          author: Site.instance.actor,
          owner: @author,
          relation_ids: [ Relation::Public.instance.id ]
        )
      end
    end

    # 2. Regular follow
    assert_difference -> { @author.notifications.count } => 1 do
      perform_enqueued_jobs do
        Activity.create!(
          verb: :follow,
          author: @owner,
          owner: @author,
          relation_ids: [ Relation::Public.instance.id ]
        )
      end
    end

    # Clear notifications
    @author.notifications.destroy_all

    # 3. Reciprocal follow (make_friend)
    assert_difference -> { @author.notifications.count } => 1 do
      perform_enqueued_jobs do
        Activity.create!(
          verb: :make_friend,
          author: @owner,
          owner: @author,
          relation_ids: [ Relation::Public.instance.id ]
        )
      end
    end
    
    # Assert the notification has the right content
    notification = @author.notifications.reload.last
    assert_equal "NewFollowerNotifier::Notification", notification.type
    assert_equal "bob começou a seguir você.", notification.message
  end
end
