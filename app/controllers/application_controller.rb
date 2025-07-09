class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include CheckoutAnalytics
  include UserJourneyTracker

  before_action :set_session_start_time
  before_action :current_user
  before_action :cart_item_count

  private

  def set_session_start_time
    session[:started_at] ||= Time.current.iso8601
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      flash[:alert] = "You must be logged in to access this page"
      redirect_to login_path
    end
  end

  def require_admin
    unless logged_in? && current_user.admin?
      flash[:alert] = "You must be an admin to access this page"
      redirect_to root_path
    end
  end

  def cart_items
    if logged_in?
      @current_user.cart_items
    else
      CartItem.for_session(session.id.to_s)
    end
  end

  def cart_item_count
    @cart_item_count = cart_items.sum(:quantity)
  end

  def detect_potential_abandonment
    return unless cart_items.any?

    # Detect high-risk abandonment scenarios
    warning_signals = count_warning_signals

    if warning_signals >= 2
      Appsignal.increment_counter(
        "abandonment.risk_detected",
        1,
        {
          warning_signals: warning_signals,
          risk_level: warning_signals >= 3 ? "high" : "medium",
          current_step: determine_funnel_position,
          **session_behavior_patterns
        }
      )
    end
  end

  def session_behavior_patterns
    {
      is_mobile: request.user_agent.match?(/Mobile/),
      is_repeat_visitor: session[:journey_steps]&.length.to_i > 10,
      has_search_behavior: session[:journey_steps]&.any? { |s| s[:path].include?("search") },
      referrer_type: classify_referrer(request.referer),
      time_of_day: Time.current.hour,
      day_of_week: Time.current.wday
    }
  end

  def classify_referrer(referrer)
    return "direct" unless referrer

    case referrer
    when /google/ then "search_engine"
    when /facebook|twitter|instagram/ then "social_media"
    when /\.com/ then "external_website"
    else "other"
    end
  end

  helper_method :current_user, :logged_in?, :cart_items, :cart_item_count
end
