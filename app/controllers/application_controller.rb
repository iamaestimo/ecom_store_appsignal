class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :current_user
  before_action :cart_item_count

  private

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def logged_in?
    !!current_user
  end

  def require_login
    unless logged_in?
      flash[:alert] = "You must be logged in to access this page"
      redirect_to login_path
    end
  end

  def cart_items
    if logged_in?
      @current_user.cart_items
    else
      CartItem.for_session(session.id.to_s)
    end
  end

  def cart_item_count
    @cart_item_count = cart_items.sum(:quantity)
  end

  helper_method :current_user, :logged_in?, :cart_items, :cart_item_count
end
