# Service object that creates a {Group} and wires it into the social graph in a single
# transaction: it builds the group's backing {ActivityObject}, then connects the group's
# {Actor} to its creator through the +admin+ relation.
#
# @see Group
# @see Actor#connect_to
class GroupCreation
  # @param creator_actor [Actor] the actor founding the group (becomes its admin).
  # @param group [Group] an unsaved group to persist.
  def initialize(creator_actor, group)
    @creator = creator_actor
    @group = group
  end

  # Persists the group, its activity object and the admin tie to the creator.
  #
  # @return [Group] the persisted group.
  # @raise [ActiveRecord::RecordInvalid] if any record fails validation (rolls back the transaction).
  def call
    ActiveRecord::Base.transaction do
      @group.save!

      activity_object = ActivityObject.create!(
        objectable: @group,
        title: @group.name,
        description: @group.description
      )

      @group.actor.update!(activity_object: activity_object)
      @group.actor.connect_to(@creator, as: "owner")

      @group
    end
  end
end
