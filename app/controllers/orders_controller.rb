class OrdersController < ApplicationController
  before_action :require_login

  def index
    @orders = current_user.orders.order(created_at: :desc)
  end

  def show
    @order = current_user.orders.find(params[:id])
  end

  def new
    @order = current_user.orders.build
    @cart_items = current_user.cart_items.includes(:product)
    @cart_total = current_user.cart_total

    if @cart_items.empty?
      flash[:alert] = "Your cart is empty."
      redirect_to cart_path
    end
  end

  def create
    @cart_items = current_user.cart_items.includes(:product)

    if @cart_items.empty?
      flash[:alert] = "Your cart is empty."
      redirect_to cart_path
      return
    end

    @order = current_user.orders.build(order_params)
    @order.total = current_user.cart_total

    ActiveRecord::Base.transaction do
      if @order.save
        # Create order items from cart items
        @cart_items.each do |cart_item|
          @order.order_items.create!(
            product: cart_item.product,
            quantity: cart_item.quantity,
            price: cart_item.product.price
          )
        end

        # Clear the cart
        @cart_items.destroy_all

        flash[:notice] = "Order placed successfully!"
        redirect_to @order
      else
        @cart_total = current_user.cart_total
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    flash[:alert] = "There was an error processing your order: #{e.message}"
    redirect_to new_order_path
  end

  private

  def order_params
    params.require(:order).permit(:name, :email)
  end
end
