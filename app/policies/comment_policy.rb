# Authorization policy for {Comment Comments}.
# Allows any signed-in actor to create, upvote, downvote, or flag comments.
# Only the author may update/edit a comment.
# The author or the wall owner (owner of the comment object) may delete/destroy it.
class CommentPolicy < ApplicationPolicy
  def create?
    return false unless user.present? && actor.present?

    owner = record.activity_object&.owner
    return true if owner.nil?
    return true if owner == actor

    if owner.actorable_type == "Group"
      actor.can?(:create, :comment, owner)
    else
      true
    end
  end

  def reply?
    create?
  end

  def update?
    actor && record.author_id == actor.id
  end

  def destroy?
    author_or_owner?
  end

  def upvote?
    user.present? && actor.present?
  end

  def downvote?
    user.present? && actor.present?
  end

  def flag?
    user.present? && actor.present?
  end

  def flag_form?
    flag?
  end

  def unflag?
    user.present? && actor.present?
  end
end
