class CartController < ApplicationController
  include CheckoutAnalytics
  include UserJourneyTracker
  def show
    @cart_items = cart_items.includes(:product)
    @cart_total = calculate_cart_total

    # Enhanced cart view tracking
    track_cart_analysis
    track_event("cart_viewed", enhanced_cart_metadata)
  end

  def add
    @product = Product.find(params[:product_id])

    # Track pre-add behavior
    track_pre_add_behavior

    if logged_in?
      @cart_item = current_user.cart_items.find_by(product: @product)
    else
      @cart_item = CartItem.find_by(product: @product, session_id: session.id.to_s)
    end

    if @cart_item
      old_quantity = @cart_item.quantity
      @cart_item.increment!(:quantity)

      track_event("cart_quantity_increased", {
        product_id: @product.id,
        product_name: @product.name,
        old_quantity: old_quantity,
        new_quantity: @cart_item.quantity,
        **enhanced_cart_metadata
      })
    else
      cart_params = {
        product: @product,
        quantity: 1
      }

      if logged_in?
        cart_params[:user] = current_user
      else
        cart_params[:session_id] = session.id.to_s
      end

      @cart_item = CartItem.create!(cart_params)

      track_event("item_added_to_cart", {
        product_id: @product.id,
        product_name: @product.name,
        product_price: @product.price,
        product_category: @product.category,
        is_first_item: cart_items.count == 1,
        **enhanced_cart_metadata
      })
    end

    flash[:notice] = "#{@product.name} added to cart!"
    redirect_to @product
  end

  def update
    @cart_item = find_cart_item(params[:id])
    old_quantity = @cart_item.quantity

    if @cart_item.update(quantity: params[:quantity])
      track_event("cart_item_quantity_changed", {
        product_id: @cart_item.product.id,
        old_quantity: old_quantity,
        new_quantity: @cart_item.quantity,
        change_type: params[:quantity].to_i > old_quantity ? "increase" : "decrease",
        **enhanced_cart_metadata
      })

      flash[:notice] = "Cart updated!"
    else
      track_event("cart_update_failed", {
        product_id: @cart_item.product.id,
        attempted_quantity: params[:quantity],
        error: @cart_item.errors.full_messages.join(", ")
      })

      flash[:alert] = "Unable to update cart."
    end

    redirect_to cart_path
  end

  def remove
    @cart_item = find_cart_item(params[:id])

    track_event("cart_item_removed", {
      product_id: @cart_item.product.id,
      product_name: @cart_item.product.name,
      quantity_removed: @cart_item.quantity,
      item_value: @cart_item.total_price,
      remaining_items: cart_items.count - 1,
      **enhanced_cart_metadata
    })

    @cart_item.destroy

    flash[:notice] = "Item removed from cart."
    redirect_to cart_path
  end

  def clear
    items_count = cart_items.count
    total_value = calculate_cart_total

    track_event("cart_cleared", {
      items_cleared: items_count,
      value_cleared: total_value,
      clear_reason: "manual",
      **enhanced_cart_metadata
    })

    cart_items.destroy_all
    flash[:notice] = "Cart cleared."
    redirect_to cart_path
  end

  private

  def find_cart_item(id)
    cart_items.find(id)
  end

  def calculate_cart_total
    if logged_in?
      current_user.cart_total
    else
      cart_items.sum { |item| item.quantity * item.product.price }
    end
  end

  def track_pre_add_behavior
    product_views = session[:journey_steps]&.count { |step|
      step[:path] == product_path(@product)
    } || 0

    time_on_product_page = if session[:journey_steps]&.last&.dig(:path) == product_path(@product)
      last_timestamp = session[:journey_steps].last[:timestamp]
      # Handle both string and Time objects
      parsed_time = last_timestamp.is_a?(String) ? Time.parse(last_timestamp) : last_timestamp
      Time.current - parsed_time
    else
      0
    end

    Appsignal.increment_counter(
      "cart.pre_add_behavior",
      1,
      {
        product_id: @product.id,
        product_views_in_session: product_views,
        time_on_product_page: time_on_product_page.to_i,
        session_page_count: session[:journey_steps]&.length || 0,
        came_from: session[:journey_steps]&.last&.dig(:path) || "unknown"
      }
    )
  end

  def track_cart_analysis
    return unless @cart_items.any?

    # Analyze cart composition
    categories = @cart_items.map { |item| item.product.category }.uniq
    price_range = @cart_items.map { |item| item.product.price }

    # Track cart hesitation patterns
    cart_modifications = session[:journey_steps]&.count { |step|
      step[:controller] == "cart" && [ "update", "remove" ].include?(step[:action])
    } || 0

    cart_views_in_session = session[:journey_steps]&.count { |step|
      step[:path] == "/cart"
    } || 0

    Appsignal.set_gauge(
      "cart.composition_analysis",
      @cart_total,
      {
        item_count: @cart_items.count,
        unique_categories: categories.length,
        price_range_min: price_range.min,
        price_range_max: price_range.max,
        avg_item_price: price_range.sum / price_range.length,
        cart_modifications: cart_modifications,
        cart_views_this_session: cart_views_in_session,
        hesitation_score: calculate_hesitation_score
      }
    )
  end

  def calculate_hesitation_score
    # Higher score = more hesitation
    score = 0

    # Multiple cart views
    cart_views = session[:journey_steps]&.count { |s| s[:path] == "/cart" } || 0
    score += [ cart_views - 1, 0 ].max * 10

    # Cart modifications
    modifications = session[:journey_steps]&.count { |s|
      s[:controller] == "cart" && [ "update", "remove" ].include?(s[:action])
    } || 0
    score += modifications * 15

    # Time spent on cart without action
    if session[:journey_steps]&.last&.dig(:path) == "/cart"
      last_timestamp = session[:journey_steps].last[:timestamp]
      # Handle both string and Time objects
      parsed_time = last_timestamp.is_a?(String) ? Time.parse(last_timestamp) : last_timestamp
      time_on_cart = Time.current - parsed_time
      score += [ time_on_cart / 60 - 2, 0 ].max * 5 # Points for time over 2 minutes
    end

    score.to_i
  end

  def enhanced_cart_metadata
    {
      cart_value: calculate_cart_total,
      item_count: cart_items.count,
      session_duration: session_duration,
      pages_in_session: session[:journey_steps]&.length || 0,
      user_type: logged_in? ? "authenticated" : "guest",
      hesitation_score: calculate_hesitation_score,
      journey_path: session[:journey_steps]&.last(5)&.map { |s| "#{s[:controller]}##{s[:action]}" }&.join(" → ")
    }
  end

  # def track_checkout_funnel_step(step, metadata = {})
  #   base_metadata = {
  #     session_id: session.id.to_s,
  #     user_id: current_user&.id,
  #     timestamp: Time.current.iso8601
  #   }

  #   # AppSignal custom metric for funnel tracking
  #   Appsignal.increment_counter("checkout_funnel.step", 1, {
  #     step: step,
  #     **base_metadata.merge(metadata)
  #   })

  #   # Log for debugging
  #   Rails.logger.info("Checkout Funnel: #{step} - #{base_metadata.merge(metadata)}")
  # end
end
