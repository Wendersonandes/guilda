module ApplicationHelper
  include Pagy::Frontend

  def activity_description(activity)
    I18n.t("activity.description.#{activity.verb}",
      author: activity.author.name,
      owner: activity.owner.name,
      default: nil
    )
  end

  def state_code_for(state)
    return nil if state.blank?

    states_hash = CS.states(:BR) || {}
    if states_hash.key?(state.to_sym)
      state.to_s
    else
      (states_hash.key(state) || state).to_s
    end
  end
end
