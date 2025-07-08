class Admin::ProductsController < Admin::BaseController
  before_action :set_product, only: [ :show, :edit, :update, :destroy ]

  def index
    @products = Product.all.order(created_at: :desc)
    @products = @products.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    @products = @products.where(category: params[:category]) if params[:category].present?
    @categories = Product.distinct.pluck(:category).compact
  end

  def show
  end

  def new
    @product = Product.new
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      flash[:notice] = "Product created successfully!"
      redirect_to admin_product_path(@product)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      flash[:notice] = "Product updated successfully!"
      redirect_to admin_product_path(@product)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    # Handle image removal if image_id is provided
    if params[:image_id]
      image = @product.images.find(params[:image_id])
      image.purge
      flash[:notice] = "Image removed successfully!"
      redirect_to edit_admin_product_path(@product)
    else
      @product.destroy
      flash[:notice] = "Product deleted successfully!"
      redirect_to admin_products_path
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :description, :price, :category, :active, images: [])
  end
end
