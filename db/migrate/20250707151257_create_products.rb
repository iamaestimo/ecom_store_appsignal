class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name
      t.text :description
      t.decimal :price, precision: 10, scale: 2, null: false
      t.string :category
      t.boolean :active, default: true

      t.timestamps
    end
    add_index :products, :category
    add_index :products, :active
  end
end
