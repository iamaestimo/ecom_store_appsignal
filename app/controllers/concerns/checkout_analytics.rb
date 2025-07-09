module CheckoutAnalytics
  extend ActiveSupport::Concern

  def track_event(event_name, metadata = {})
    base_metadata = {
      session_id: session.id.to_s,
      user_id: current_user&.id,
      timestamp: Time.current.iso8601,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    }

    # AppSignal custom metric for funnel tracking
    Appsignal.increment_counter("checkout_funnel.step", 1, {
      step: event_name,
      **base_metadata.merge(metadata)
    })

    # Set gauge for real-time funnel monitoring
    Appsignal.set_gauge("checkout_funnel.current_step", funnel_step_value(event_name), {
      session_id: session.id.to_s
    })

    # Log for debugging and backup analytics
    Rails.logger.info("Checkout Funnel: #{event_name} - #{base_metadata.merge(metadata)}")
  end

  def track_abandonment_with_journey(step, reason = "unknown")
    journey_analysis = analyze_abandonment_journey

    Appsignal.increment_counter(
      "checkout.abandonment_with_context",
      1,
      {
        abandonment_step: step,
        abandonment_reason: reason,
        **journey_analysis,
        **session_behavior_patterns,
        **cart_analysis_data
      }
    )

    # Also track the specific journey patterns that led to abandonment
    Appsignal.increment_counter(
      "abandonment.journey_patterns",
      1,
      {
        journey_pattern: extract_journey_pattern,
        warning_signals: count_warning_signals,
        engagement_level: calculate_engagement_level
      }
    )
  end

  private

  def analyze_abandonment_journey
    return {} unless session[:journey_steps]

    steps = session[:journey_steps]

    {
      total_pages_viewed: steps.length,
      session_duration_minutes: session_duration / 60,
      unique_products_viewed: count_unique_products_viewed(steps),
      cart_interactions: count_cart_interactions(steps),
      authentication_attempts: count_auth_attempts(steps),
      back_and_forth_behavior: detect_back_and_forth(steps),
      time_between_cart_and_abandonment: time_since_last_cart_view(steps)
    }
  end

  def session_behavior_patterns
    {
      is_mobile: request.user_agent.match?(/Mobile/),
      is_repeat_visitor: session[:journey_steps]&.length.to_i > 10,
      has_search_behavior: session[:journey_steps]&.any? { |s| s[:path].include?("search") },
      referrer_type: classify_referrer(request.referrer),
      time_of_day: Time.current.hour,
      day_of_week: Time.current.wday
    }
  end

  def cart_analysis_data
    return {} unless cart_items.any?

    {
      cart_value_range: classify_cart_value(calculate_cart_total),
      has_high_value_items: cart_items.any? { |item| item.product.price > 100 },
      cart_item_diversity: cart_items.map(&:product).map(&:category).uniq.length,
      average_time_per_item: session_duration / cart_items.count
    }
  end

  def extract_journey_pattern
    return "unknown" unless session[:journey_steps]

    pattern = session[:journey_steps].last(5).map { |step|
      case step[:path]
      when "/" then "H"
      when /\/products/ then "P"
      when "/cart" then "C"
      when "/orders/new" then "O"
      when /\/(login|signup)/ then "A"
      else "X"
      end
    }.join

    # Classify common patterns
    case pattern
    when /H.*P.*C$/ then "browse_add_abandon"
    when /P.*C.*P/ then "comparison_shopping"
    when /C.*C.*C/ then "cart_hesitation"
    when /C.*A/ then "auth_barrier"
    else pattern
    end
  end

  def count_warning_signals
    signals = 0
    return signals unless session[:journey_steps]

    # Multiple cart views without progression
    cart_views = session[:journey_steps].count { |s| s[:path] == "/cart" }
    signals += 1 if cart_views > 2

    # Rapid back-and-forth between pages
    signals += 1 if detect_back_and_forth(session[:journey_steps])

    # Long session without purchasing
    signals += 1 if session_duration > 20.minutes

    # Cart modifications (quantity changes, removals)
    modifications = session[:journey_steps].count { |s|
      s[:controller] == "cart" && [ "update", "remove" ].include?(s[:action])
    }
    signals += 1 if modifications > 1

    signals
  end

  def calculate_engagement_level
    return "low" unless session[:journey_steps]

    score = 0
    steps = session[:journey_steps]

    # Points for different activities
    score += steps.count { |s| s[:controller] == "products" } * 2
    score += steps.count { |s| s[:controller] == "cart" } * 3
    score += steps.length
    score += session_duration / 60

    case score
    when 0..10 then "low"
    when 11..25 then "medium"
    when 26..50 then "high"
    else "very_high"
    end
  end

  def count_unique_products_viewed(steps)
    steps.select { |s| s[:path].match?(/\/products\/\d+/) }
         .map { |s| s[:path] }
         .uniq
         .count
  end

  def count_cart_interactions(steps)
    steps.count { |s| s[:controller] == "cart" }
  end

  def count_auth_attempts(steps)
    steps.count { |s| s[:path].match?(/\/(login|signup)/) }
  end

  def detect_back_and_forth(steps)
    return false if steps.length < 4

    # Look for patterns like A→B→A→B
    recent_steps = steps.last(4).map { |s| s[:path] }
    recent_steps[0] == recent_steps[2] && recent_steps[1] == recent_steps[3]
  end

  def time_since_last_cart_view(steps)
    last_cart_step = steps.reverse.find { |s| s[:path] == "/cart" }
    return 0 unless last_cart_step

    last_timestamp = last_cart_step[:timestamp]
    # Handle both string and Time objects
    parsed_time = last_timestamp.is_a?(String) ? Time.parse(last_timestamp) : last_timestamp
    (Time.current - parsed_time).to_i
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

  def classify_cart_value(value)
    case value
    when 0..25 then "low"
    when 26..100 then "medium"
    when 101..500 then "high"
    else "very_high"
    end
  end

  def funnel_step_value(step)
    # Assign numeric values to steps for progression tracking
    step_values = {
      "cart_viewed" => 1,
      "checkout_initiated" => 2,
      "checkout_form_viewed" => 3,
      "order_completed" => 4,
      "checkout_abandoned" => -1,
      "item_added_to_cart" => 0.5,
      "cart_quantity_increased" => 0.6,
      "cart_item_removed" => -0.1
    }
    step_values[step] || 0
  end

  def session_duration
    return 0 unless session[:started_at]
    (Time.current - Time.parse(session[:started_at])).to_i
  rescue
    0
  end

  def count_warning_signals
    signals = 0
    return signals unless session[:journey_steps]

    # Multiple cart views without progression
    cart_views = session[:journey_steps].count { |s| s[:path] == "/cart" }
    signals += 1 if cart_views > 2

    # Rapid back-and-forth between pages
    signals += 1 if detect_back_and_forth(session[:journey_steps])

    # Long session without purchasing
    signals += 1 if session_duration > 20.minutes

    # Cart modifications (quantity changes, removals)
    modifications = session[:journey_steps].count { |s|
      s[:controller] == "cart" && [ "update", "remove" ].include?(s[:action])
    }
    signals += 1 if modifications > 1

    signals
  end

  def determine_funnel_position
    case request.path
    when "/" then "homepage"
    when /\/products\/\d+/ then "product_view"
    when "/cart" then "cart_view"
    when "/orders/new" then "checkout_form"
    when /\/orders\/\d+/ then "order_complete"
    when /\/(login|signup)/ then "authentication"
    else "other"
    end
  end
end
