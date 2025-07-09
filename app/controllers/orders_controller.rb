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
      # Track cart abandonment - user reached checkout with empty cart
      track_checkout_funnel_step("checkout_abandoned_empty_cart")
      flash[:alert] = "Your cart is empty."
      redirect_to cart_path
      return
    end

    # Track checkout initiation
    track_checkout_funnel_step("checkout_initiated", {
      items_count: @cart_items.count,
      cart_total: @cart_total.to_f,
      cart_items: @cart_items.map { |item|
        {
          product_id: item.product.id,
          product_name: item.product.name,
          quantity: item.quantity,
          price: item.product.price.to_f
        }
      }
    })
  end

  def create
    @cart_items = current_user.cart_items.includes(:product)

    if @cart_items.empty?
      track_checkout_funnel_step("checkout_abandoned_empty_cart")
      flash[:alert] = "Your cart is empty."
      redirect_to cart_path
      return
    end

    @order = current_user.orders.build(order_params)
    @order.total = current_user.cart_total

    # Track checkout attempt
    checkout_start_time = Time.current

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

        # Track successful order completion
        checkout_duration = Time.current - checkout_start_time
        track_checkout_funnel_step("order_completed", {
          order_id: @order.id,
          order_total: @order.total.to_f,
          items_count: @order.order_items.count,
          checkout_duration_ms: (checkout_duration * 1000).round(2),
          order_items: @order.order_items.map { |item|
            {
              product_id: item.product.id,
              product_name: item.product.name,
              quantity: item.quantity,
              price: item.price.to_f
            }
          }
        })

        # Track conversion for each product
        @order.order_items.each do |item|
          Appsignal.increment_counter("product.converted", 1, {
            product_id: item.product.id,
            product_name: item.product.name,
            category: item.product.category
          })
        end

        # Clear the cart
        @cart_items.destroy_all

        flash[:notice] = "Order placed successfully!"
        redirect_to @order
      else
        # Track checkout failure
        track_checkout_funnel_step("checkout_failed", {
          errors: @order.errors.full_messages,
          cart_total: current_user.cart_total.to_f
        })

        @cart_total = current_user.cart_total
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    # Track checkout error
    track_checkout_funnel_step("checkout_error", {
      error_message: e.message,
      cart_total: current_user.cart_total.to_f
    })

    flash[:alert] = "There was an error processing your order: #{e.message}"
    redirect_to new_order_path
  end

  private

  def order_params
    params.require(:order).permit(:name, :email)
  end

  def track_checkout_funnel_step(step, metadata = {})
    base_metadata = {
      session_id: session.id.to_s,
      user_id: current_user&.id,
      timestamp: Time.current.iso8601
    }

    # AppSignal custom metric for funnel tracking
    Appsignal.increment_counter("checkout_funnel.step", 1, {
      step: step,
      **base_metadata.merge(metadata)
    })

    # Log for debugging
    Rails.logger.info("Checkout Funnel: #{step} - #{base_metadata.merge(metadata)}")
  end
end
