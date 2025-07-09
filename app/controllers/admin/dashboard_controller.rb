class Admin::DashboardController < Admin::BaseController
  def index
    @total_products = Product.count
    @total_orders = Order.count
    @total_users = User.count
    @total_revenue = Order.sum(:total)

    @recent_orders = Order.includes(:user).order(created_at: :desc).limit(5)
    @low_stock_products = Product.active.limit(5) # You can add stock tracking later

    @orders_by_status = Order.group(:status).count
    @monthly_revenue = Order.where(created_at: 1.month.ago..Time.current).sum(:total)

    # Add abandonment rate metrics
    @abandonment_rate = Rails.cache.read("abandonment_rate_#{Date.current}") || 0
    @conversion_metrics = calculate_conversion_metrics
  end

  private

  def calculate_conversion_metrics
    today = Date.current
    week_ago = 7.days.ago

    # These would ideally come from AppSignal metrics
    # For demonstration, using basic calculations
    {
      daily_cart_views: CartItem.where(created_at: today.all_day).count,
      daily_checkouts: Order.where(created_at: today.all_day).count,
      weekly_conversion_rate: calculate_weekly_conversion_rate,
      avg_time_to_checkout: calculate_avg_checkout_time
    }
  end

  def calculate_weekly_conversion_rate
    week_orders = Order.where(created_at: 7.days.ago..Time.current).count
    week_cart_items = CartItem.where(created_at: 7.days.ago..Time.current).distinct.count(:session_id)

    return 0 if week_cart_items == 0
    ((week_orders / week_cart_items.to_f) * 100).round(2)
  end

  def calculate_avg_checkout_time
    # This would ideally be tracked via the instrumentation
    # For now, return a placeholder
    "2.3 minutes"
  end
end
