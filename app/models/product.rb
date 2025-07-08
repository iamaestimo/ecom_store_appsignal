class Product < ApplicationRecord
  has_many :cart_items, dependent: :destroy
  has_many :order_items, dependent: :destroy
  has_many_attached :images

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true

  scope :active, -> { where(active: true) }
  scope :by_category, ->(category) { where(category: category) if category.present? }

  def formatted_price
    "$#{price.to_f}"
  end

  def main_image
    images.attached? ? images.first : nil
  end
end
