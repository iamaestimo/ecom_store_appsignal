class CreateCartItems < ActiveRecord::Migration[8.0]
  def change
    create_table :cart_items do |t|
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, default: 1
      t.string :session_id
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end
    add_index :cart_items, :session_id
  end
end
