class CreatePlans < ActiveRecord::Migration[8.1]
  # `plans` already exists in the deployed database; this mirrors its real
  # shape so that a from-scratch `db:migrate` builds the same table. It is a
  # no-op wherever the table is already present.
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :plans, id: :uuid, default: -> { "gen_random_uuid()" }, if_not_exists: true do |t|
      t.text :code, null: false
      t.text :name, null: false
      t.text :currency, default: "BRL", null: false
      t.integer :price_cents, default: 0, null: false
      t.integer :included_conversations, default: 500, null: false
      t.integer :max_users, default: 3, null: false
      t.integer :max_channels, default: 1, null: false
      t.integer :overage_pack_size, default: 500, null: false
      t.integer :overage_pack_price_cents, default: 19700, null: false
      t.boolean :allow_byok, default: false, null: false
      t.boolean :is_active, default: true, null: false
      t.jsonb :features, default: {}, null: false
      t.integer :sort_order, default: 0, null: false
      # The table carries no updated_at.
      t.timestamptz :created_at, default: -> { "now()" }, null: false

      t.unique_constraint [ :code ], name: "plans_code_key"
    end
  end
end
