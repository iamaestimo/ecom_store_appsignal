class CartItem < ApplicationRecord
  belongs_to :product
  belongs_to :user, optional: true

  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :product_id, uniqueness: { scope: [ :session_id, :user_id ] }

  def total_price
    quantity * product.price
  end

  def self.for_session(session_id)
    where(session_id: session_id, user_id: nil)
  end

  def self.for_user(user)
    where(user: user)
  end
end
