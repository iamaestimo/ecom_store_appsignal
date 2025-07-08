class Order < ApplicationRecord
  belongs_to :user
  has_many :order_items, dependent: :destroy
  has_many :products, through: :order_items

  validates :total, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true
  validates :email, presence: true
  validates :name, presence: true

  enum :status, { pending: "pending", processing: "processing", shipped: "shipped", delivered: "delivered", cancelled: "cancelled" }

  def formatted_total
    "$#{total.to_f}"
  end

  def item_count
    order_items.sum(:quantity)
  end
end
