# Clear existing data
puts "Clearing existing data..."
# OrderItem.destroy_all
# Order.destroy_all
# CartItem.destroy_all
# Product.destroy_all
# User.destroy_all

puts "Creating users..."
user1 = User.create!(
  name: "John Doe",
  email: "john@example.com",
  password: "password123"
)

user2 = User.create!(
  name: "Jane Smith",
  email: "jane@example.com",
  password: "password123"
)

puts "Creating products..."
products = [
  {
    name: "Wireless Headphones",
    description: "High-quality wireless headphones with noise cancellation. Perfect for music lovers and professionals who need crystal clear audio.",
    price: 199.99,
    category: "electronics"
  },
  {
    name: "Coffee Maker",
    description: "Automatic drip coffee maker with programmable timer. Makes up to 12 cups of delicious coffee.",
    price: 89.99,
    category: "appliances"
  },
  {
    name: "Running Shoes",
    description: "Comfortable running shoes with advanced cushioning technology. Perfect for daily runs and workouts.",
    price: 129.99,
    category: "sports"
  },
  {
    name: "Smartphone",
    description: "Latest smartphone with advanced camera system and all-day battery life. Stay connected wherever you go.",
    price: 699.99,
    category: "electronics"
  },
  {
    name: "Backpack",
    description: "Durable backpack with multiple compartments. Perfect for travel, work, or school.",
    price: 49.99,
    category: "accessories"
  },
  {
    name: "Desk Lamp",
    description: "Adjustable LED desk lamp with multiple brightness settings. Perfect for reading and working.",
    price: 39.99,
    category: "home"
  },
  {
    name: "Water Bottle",
    description: "Insulated stainless steel water bottle that keeps drinks cold for 24 hours or hot for 12 hours.",
    price: 24.99,
    category: "accessories"
  },
  {
    name: "Bluetooth Speaker",
    description: "Portable Bluetooth speaker with excellent sound quality and 20-hour battery life.",
    price: 79.99,
    category: "electronics"
  }
]

products.each do |product_attrs|
  Product.create!(product_attrs)
end

puts "Creating sample cart items..."
CartItem.create!(
  product: Product.first,
  quantity: 2,
  user: user1
)

CartItem.create!(
  product: Product.second,
  quantity: 1,
  user: user1
)

puts "Creating sample order..."
order = Order.create!(
  user: user2,
  total: 219.98,
  status: 'delivered',
  name: user2.name,
  email: user2.email
)

OrderItem.create!(
  order: order,
  product: Product.first,
  quantity: 1,
  price: Product.first.price
)

OrderItem.create!(
  order: order,
  product: Product.third,
  quantity: 1,
  price: Product.third.price
)

puts "Seed data created successfully!"
puts "Users: #{User.count}"
puts "Products: #{Product.count}"
puts "Cart Items: #{CartItem.count}"
puts "Orders: #{Order.count}"
puts "Order Items: #{OrderItem.count}"
