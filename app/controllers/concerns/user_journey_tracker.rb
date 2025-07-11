module UserJourneyTracker
  extend ActiveSupport::Concern

  included do
    before_action :track_page_view
    before_action :track_session_progression
    after_action :update_session_metadata
  end

  private

  def track_page_view
    # Measure database time for this request
    db_start = Time.current

    db_duration = ((Time.current - db_start) * 1000).round(2)

    journey_step = {
      timestamp: Time.current,
      controller: controller_name,
      action: action_name,
      path: request.path,
      method: request.method,
      referrer: request.referrer,
      user_agent: request.user_agent,
      session_duration: session_duration,
      page_sequence: increment_page_sequence
    }

    # Store in session for abandonment analysis
    session[:journey_steps] = session[:journey_steps]&.last(10) || []

    session[:journey_steps] << {
      controller: controller_name,
      action: action_name,
      path: request.path,
      timestamp: Time.current.iso8601
    }

    # Track in AppSignal
    if db_duration > 5 # Slow query threshold
        Appsignal.increment_counter(
          "user_journey.page_view",
          1,
          {
            controller: controller_name,
            action: action_name,
            db_duration_ms: db_duration,
            funnel_step: determine_funnel_position,
            user_type: logged_in? ? "authenticated" : "guest"

            # controller: controller_name,
            # action: action_name,
            # path: request.path,
            # session_duration: session_duration,
            # page_in_session: session[:journey_steps].length,
            # has_cart_items: cart_items.any?,
            # user_type: logged_in? ? "authenticated" : "guest"
          }
        )
    end
  end

  def track_session_progression
    current_step = determine_funnel_position
    last_step = session[:last_funnel_step]

    if last_step != current_step
      track_funnel_progression(last_step, current_step)
      session[:last_funnel_step] = current_step
    end
  end

  def determine_funnel_position
    case
    when request.path == "/" then "homepage"
    when request.path.match?(/\/products\/\d+/) then "product_view"
    when request.path == "/cart" then "cart_view"
    when request.path == "/orders/new" then "checkout_form"
    when request.path.match?(/\/orders\/\d+/) then "order_complete"
    when request.path.match?(/\/(login|signup)/) then "authentication"
    else "other"
    end
  end

  def track_funnel_progression(from, to)
    cart_value = begin
      if logged_in?
        current_user.cart_total
      else
        cart_items.sum { |item| item.quantity * item.product.price }
      end
    rescue
      0
    end

    Appsignal.increment_counter(
      "user_journey.funnel_progression",
      1,
      {
        from_step: from,
        to_step: to,
        session_duration: session_duration,
        pages_viewed: session[:journey_steps]&.length || 0,
        cart_value: cart_value,
        progression_type: classify_progression(from, to)
      }
    )
  end

  def classify_progression(from, to)
    positive_flows = {
      "homepage" => [ "product_view" ],
      "product_view" => [ "cart_view" ],
      "cart_view" => [ "checkout_form", "authentication" ],
      "authentication" => [ "checkout_form" ],
      "checkout_form" => [ "order_complete" ]
    }

    if positive_flows[from]&.include?(to)
      "forward"
    elsif from == to
      "same_page"
    else
      "backward_or_exit"
    end
  end

  def session_duration
    return 0 unless session[:started_at]
    (Time.current - Time.parse(session[:started_at])).to_i
  end

  def increment_page_sequence
    session[:page_sequence] = (session[:page_sequence] || 0) + 1
  end

  def update_session_metadata
    session[:last_activity] = Time.current.to_s

    # Track session health metrics
    Appsignal.set_gauge(
      "session.health.duration",
      session_duration,
      {
        pages_viewed: session[:journey_steps]&.length || 0,
        has_cart: cart_items.any?,
        user_type: logged_in? ? "authenticated" : "guest"
      }
    )
  end
end
