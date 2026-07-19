class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [ :update ]

  # GET /notifications
  def index
    authorize Noticed::Notification, policy_class: Noticed::NotificationPolicy
    @notifications = policy_scope(Noticed::Notification).includes(:event).order(created_at: :desc)

    @authors = Actor.where(id: policy_scope(Noticed::Notification)
                                 .joins(:event)
                                 .joins("INNER JOIN activities ON activities.id = (SUBSTRING(noticed_events.params -> 'activity' ->> '_aj_globalid' FROM 'gid://.*/Activity/([0-9]+)')::bigint)")
                                 .select("activities.author_id")
                                 .distinct)

    prepare_ransack_params
    @q = @notifications.ransack(params[:q])
    @notifications = @q.result(distinct: true)
    @pagy, @notifications = pagy(@notifications, limit: 15)
  end

  # PATCH /notifications/:id
  def update
    authorize @notification, policy_class: Noticed::NotificationPolicy
    @notification.mark_as_read

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(@notification, partial: "notifications/notification", locals: { notification: @notification }),
          turbo_stream.replace("nav_notification_badge", partial: "shared/nav_notification_badge")
        ]
      end
      format.html { redirect_to notifications_path }
    end
  end

  # POST /notifications/mark_all_as_read
  def mark_all_as_read
    authorize Noticed::Notification, :mark_all_as_read?, policy_class: Noticed::NotificationPolicy
    base_notifications = policy_scope(Noticed::Notification)
    base_notifications.unread.mark_as_read

    respond_to do |format|
      format.turbo_stream do
        @notifications = base_notifications.includes(:event).order(created_at: :desc)
        prepare_ransack_params
        @q = @notifications.ransack(params[:q])
        @notifications = @q.result(distinct: true)
        @pagy, @notifications = pagy(@notifications, limit: 15)
        render turbo_stream: [
          turbo_stream.replace("notifications_list_container", partial: "notifications/list", locals: { notifications: @notifications, pagy: @pagy }),
          turbo_stream.replace("nav_notification_badge", partial: "shared/nav_notification_badge")
        ]
      end
      format.html { redirect_to notifications_path, notice: "All notifications marked as read." }
    end
  end

  private

  def set_notification
    @notification = Noticed::Notification.find(params[:id])
  end

  def prepare_ransack_params
    if params[:q].blank?
      params[:q] = {}
      params[:q][:by_date] = params[:date] if params[:date].present?
      params[:q][:by_author] = params[:author_id] if params[:author_id].present?
      params[:q][:by_type] = params[:notification_type] if params[:notification_type].present?
    end
  end
end
