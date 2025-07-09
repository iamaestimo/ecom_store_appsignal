class CheckoutAnalyticsJob < ApplicationJob
  queue_as :default

  def perform
    calculate_abandonment_rates
    update_funnel_metrics
    cleanup_old_sessions
  end

  private

  def calculate_abandonment_rates
    # Calculate overall abandonment rate
    today = Date.current

    # Get counts from AppSignal or your preferred data store
    checkout_initiations = get_metric_count("checkout_initiated", today)
    order_completions = get_metric_count("order_completed", today)

    if checkout_initiations > 0
      abandonment_rate = ((checkout_initiations - order_completions) / checkout_initiations.to_f) * 100

      # Send to AppSignal
      Appsignal.set_gauge("checkout.daily_abandonment_rate", abandonment_rate, {
        date: today.iso8601
      })

      # Store in cache for quick access
      Rails.cache.write("abandonment_rate_#{today}", abandonment_rate, expires_in: 1.day)

      Rails.logger.info("Daily abandonment rate: #{abandonment_rate.round(2)}%")
    end

    # Calculate abandonment by step
    calculate_step_abandonment_rates(today)
  end

  def calculate_step_abandonment_rates(date)
    steps = [ "cart_viewed", "checkout_initiated", "checkout_form_viewed", "order_completed" ]

    step_counts = steps.map do |step|
      [ step, get_metric_count(step, date) ]
    end.to_h

    # Calculate drop-off between each step
    steps.each_cons(2) do |current_step, next_step|
      current_count = step_counts[current_step]
      next_count = step_counts[next_step]

      if current_count > 0
        drop_off_rate = ((current_count - next_count) / current_count.to_f) * 100

        Appsignal.set_gauge("checkout.step_dropoff_rate", drop_off_rate, {
          from_step: current_step,
          to_step: next_step,
          date: date.iso8601
        })
      end
    end
  end

  def update_funnel_metrics
    # Calculate conversion funnel metrics
    total_sessions = get_metric_count("cart_viewed", Date.current)
    conversions = get_metric_count("order_completed", Date.current)

    if total_sessions > 0
      conversion_rate = (conversions / total_sessions.to_f) * 100

      Appsignal.set_gauge("checkout.conversion_rate", conversion_rate, {
        date: Date.current.iso8601
      })
    end

    # Calculate average order value
    if conversions > 0
      total_revenue = Order.where(created_at: Date.current.all_day).sum(:total)
      avg_order_value = total_revenue / conversions

      Appsignal.set_gauge("checkout.avg_order_value", avg_order_value, {
        date: Date.current.iso8601
      })
    end
  end

  def cleanup_old_sessions
    # Clean up old session data (older than 30 days)
    cutoff_date = 30.days.ago

    # This would depend on your session storage
    # For now, we'll just log the cleanup
    Rails.logger.info("Cleaning up session data older than #{cutoff_date}")
  end

  def get_metric_count(metric_name, date)
    # In a real implementation, you'd query AppSignal API or your metrics store
    # For now, we'll return a placeholder
    cache_key = "metric_count_#{metric_name}_#{date}"
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      # This would be replaced with actual AppSignal API call
      # or database query depending on your setup
      rand(10..100)
    end
  end
end
