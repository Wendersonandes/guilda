# Custom configurations and class reopenings for the Noticed gem.
Rails.application.config.to_prepare do
  # 1. Reopen Noticed::Event to broadcast on creation (bypasses Notification insert_all callback limitation)
  Noticed::Event.class_eval do
    after_create_commit :broadcast_notifications_badge_update

    private

    def broadcast_notifications_badge_update
      notifications.each do |notification|
        recipient = notification.recipient
        next unless recipient.is_a?(Actor)

        Turbo::StreamsChannel.broadcast_replace_to(
          recipient,
          :notifications,
          target: "nav_notification_badge",
          partial: "shared/nav_notification_badge",
          locals: { actor: recipient }
        )
      end
    end
  end

  # 2. Reopen Noticed::Notification to broadcast on update/destroy (for marking as read/unread) and configure Ransack
  Noticed::Notification.class_eval do
    after_commit :broadcast_badge_update, on: [ :update, :destroy ]

    scope :by_date, ->(date_param) {
      return all if date_param.blank?
      case date_param
      when "hoje"
        where("noticed_notifications.created_at >= ?", Time.current.beginning_of_day)
      when "7_days"
        where("noticed_notifications.created_at >= ?", 7.days.ago.beginning_of_day)
      when "15_days"
        where("noticed_notifications.created_at >= ?", 15.days.ago.beginning_of_day)
      else
        all
      end
    }

    scope :by_author, ->(author_id) {
      return all if author_id.blank?
      joins(:event)
        .joins("INNER JOIN activities ON activities.id = (SUBSTRING(noticed_events.params -> 'activity' ->> '_aj_globalid' FROM 'gid://.*/Activity/([0-9]+)')::bigint)")
        .where("activities.author_id = ?", author_id)
    }

    scope :by_type, ->(type_param) {
      return all if type_param.blank?
      case type_param
      when "new_follower"
        where(type: "NewFollowerNotifier::Notification")
      when "like"
        where(type: "ObjectLikedNotifier::Notification")
      when "comment"
        where(type: "ObjectCommentedNotifier::Notification")
      when "group_post"
        joins(:event)
          .joins("INNER JOIN activities ON activities.id = (SUBSTRING(noticed_events.params -> 'activity' ->> '_aj_globalid' FROM 'gid://.*/Activity/([0-9]+)')::bigint)")
          .where(type: "PostPublishedNotifier::Notification")
          .where("activities.owner_id IN (SELECT id FROM actors WHERE actorable_type = 'Group')")
      else
        all
      end
    }

    def self.ransackable_scopes(auth_object = nil)
      [:by_date, :by_author, :by_type]
    end

    def self.ransackable_attributes(auth_object = nil)
      ["created_at", "type"]
    end

    def self.ransackable_associations(auth_object = nil)
      ["event"]
    end

    private

    def broadcast_badge_update
      return unless recipient.is_a?(Actor)

      Turbo::StreamsChannel.broadcast_replace_to(
        recipient,
        :notifications,
        target: "nav_notification_badge",
        partial: "shared/nav_notification_badge",
        locals: { actor: recipient }
      )
    end
  end

  # 3. Reopen Noticed::Event to configure Ransack
  Noticed::Event.class_eval do
    def self.ransackable_attributes(auth_object = nil)
      ["type"]
    end

    def self.ransackable_associations(auth_object = nil)
      []
    end
  end
end
