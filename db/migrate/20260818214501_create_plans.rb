class CreatePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :plans, if_not_exists: true do |t|
      t.string :name, null: false
      t.string :stripe_price_id
      t.integer :max_users
      t.integer :max_channels
      t.integer :monthly_conversation_quota
      t.integer :price_cents

      t.timestamps
    end
  end
end
