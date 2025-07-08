class User < ApplicationRecord
  has_secure_password

  has_many :orders, dependent: :destroy
  has_many :cart_items, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: %w[customer admin] }

  before_validation :set_default_role, on: :create

  def cart_total
    cart_items.sum { |item| item.quantity * item.product.price }
  end

  def admin?
    role == "admin"
  end

  def customer?
    role == "customer"
  end

  private

  def set_default_role
    self.role ||= "customer"
  end
end
