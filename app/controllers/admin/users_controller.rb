class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [ :show, :edit, :update ]

  def index
    @users = User.all.order(created_at: :desc)
    @users = @users.where("name ILIKE ? OR email ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%") if params[:search].present?
    @users = @users.where(role: params[:role]) if params[:role].present?
  end

  def show
    @user_orders = @user.orders.order(created_at: :desc).limit(10)
  end

  def edit
  end

  def update
    if @user.update(user_params)
      flash[:notice] = "User updated successfully!"
      redirect_to admin_user_path(@user)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :role)
  end
end
