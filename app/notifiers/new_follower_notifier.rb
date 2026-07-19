class NewFollowerNotifier < ApplicationNotifier
  validate :activity_is_follow

  private

  def activity_is_follow
    if params[:activity] && !(params[:activity].verb_follow? || params[:activity].verb_make_friend?)
      errors.add(:base, "Activity must be a follow or make_friend")
    end
  end

  notification_methods do
    def message
      activity = params[:activity]
      if activity&.author
        I18n.t("notifications.new_follower.message", author: activity.author.name)
      else
        I18n.t("notifications.new_follower.default_message")
      end
    end

    def url
      activity = params[:activity]
      if activity&.author
        Rails.application.routes.url_helpers.profile_path(activity.author)
      else
        Rails.application.routes.url_helpers.root_path
      end
    end
  end
end
