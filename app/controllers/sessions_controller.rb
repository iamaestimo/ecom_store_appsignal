class SessionsController < ApplicationController
  def new; end

  def create
    user = User.find_by(email: params[:email])

    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      transfer_cart_to_user(user)
      flash[:notice] = "Welcome back!"
      redirect_to root_path
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    flash[:notice] = "You have been logged out."
    redirect_to root_path
  end

  private

  def transfer_cart_to_user(user)
    CartItem.for_session(session.id.to_s).update_all(user_id: user.id, session_id: nil)
  end
end
