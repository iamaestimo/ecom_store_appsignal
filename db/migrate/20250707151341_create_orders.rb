class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :total, precision: 10, scale: 2
      t.string :status, default: 'pending'
      t.string :email
      t.string :name

      t.timestamps
    end
    add_index :orders, :status
  end
end
