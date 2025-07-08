class UsersController < ApplicationController
  before_action :require_login, except: [ :new, :create ]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      session[:user_id] = @user.id
      transfer_cart_to_user
      flash[:notice] = "Welcome! Your account has been created."
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @user = current_user
  end

  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(user_params)
      flash[:notice] = "Your profile has been updated."
      redirect_to @user
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def transfer_cart_to_user
    CartItem.for_session(session.id.to_s).update_all(user_id: @user.id, session_id: nil)
  end
end
