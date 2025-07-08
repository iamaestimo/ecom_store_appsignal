class Admin::OrdersController < Admin::BaseController
  before_action :set_order, only: [ :show, :update ]

  def index
    @orders = Order.includes(:user).order(created_at: :desc)
    @orders = @orders.where(status: params[:status]) if params[:status].present?
    @orders = @orders.joins(:user).where("users.name ILIKE ? OR users.email ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?

    @order_statuses = Order.statuses.keys
  end

  def show
    @order_items = @order.order_items.includes(:product)
  end

  def update
    if @order.update(order_params)
      flash[:notice] = "Order status updated successfully!"
      redirect_to admin_order_path(@order)
    else
      flash[:alert] = "Failed to update order status."
      redirect_to admin_order_path(@order)
    end
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def order_params
    params.require(:order).permit(:status)
  end
end
