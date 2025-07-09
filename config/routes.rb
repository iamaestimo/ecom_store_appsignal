Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "products#index"

  # Authentication routes
  get "signup", to: "users#new"
  post "signup", to: "users#create"
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Product routes
  resources :products, only: [ :index, :show ]

  # Cart routes
  get "cart", to: "cart#show"
  post "cart/add/:product_id", to: "cart#add", as: "add_to_cart"
  patch "cart/update/:id", to: "cart#update", as: "update_cart_item"
  delete "cart/remove/:id", to: "cart#remove", as: "remove_from_cart"
  delete "cart/clear", to: "cart#clear", as: "clear_cart"

  # Order routes
  resources :orders, only: [ :index, :show, :new, :create ]

  # User routes
  resources :users, only: [ :show, :edit, :update ]
  post "analytics/track", to: "analytics#track"

  # Admin routes
  namespace :admin do
    root "dashboard#index"
    resources :products
    resources :orders, only: [ :index, :show, :update ]
    resources :users, only: [ :index, :show, :edit, :update ]
  end
end
