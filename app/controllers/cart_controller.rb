class CartController < ApplicationController
  def show
    @cart_items = cart_items.includes(:product)
    @cart_total = calculate_cart_total
  end

  def add
    @product = Product.find(params[:product_id])

    if logged_in?
      @cart_item = current_user.cart_items.find_by(product: @product)
    else
      @cart_item = CartItem.find_by(product: @product, session_id: session.id.to_s)
    end

    if @cart_item
      @cart_item.increment!(:quantity)
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
    end

    flash[:notice] = "#{@product.name} added to cart!"
    redirect_to @product
  end

  def update
    @cart_item = find_cart_item(params[:id])

    if @cart_item.update(quantity: params[:quantity])
      flash[:notice] = "Cart updated!"
    else
      flash[:alert] = "Unable to update cart."
    end

    redirect_to cart_path
  end

  def remove
    @cart_item = find_cart_item(params[:id])
    @cart_item.destroy

    flash[:notice] = "Item removed from cart."
    redirect_to cart_path
  end

  def clear
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
end
