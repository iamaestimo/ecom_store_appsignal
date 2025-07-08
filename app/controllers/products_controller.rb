class ProductsController < ApplicationController
  def index
    @products = Product.active.includes(images_attachments: :blob)
    @products = @products.by_category(params[:category]) if params[:category].present?
    @categories = Product.distinct.pluck(:category).compact
  end

  def show
    @product = Product.find(params[:id])
  end
end
