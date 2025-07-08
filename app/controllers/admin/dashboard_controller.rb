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
  end
end
