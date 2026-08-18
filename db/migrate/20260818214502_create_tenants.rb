class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants, if_not_exists: true do |t|
      t.string :name, null: false
      t.references :plan, foreign_key: true
      t.string :status, null: false, default: "trial"
      t.string :stripe_customer_id

      t.timestamps
    end
  end
end
