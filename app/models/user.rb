class User < ApplicationRecord
  has_secure_password

  has_many :orders, dependent: :destroy
  has_many :cart_items, dependent: :destroy

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def cart_total
    cart_items.sum { |item| item.quantity * item.product.price }
  end
end
