class Admin::BaseController < ApplicationController
  before_action :require_admin
  layout "admin"

  private

  def require_admin
    unless logged_in? && current_user.admin?
      flash[:alert] = "You must be an admin to access this page"
      redirect_to root_path
    end
  end
end
