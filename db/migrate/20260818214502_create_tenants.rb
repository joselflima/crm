class CreateTenants < ActiveRecord::Migration[8.1]
  # Mirrors the real, already-deployed `tenants` table (see CreatePlans for
  # why these migrations are written defensively).
  def change
    create_enum :tenant_status, %w[trial active past_due suspended canceled]

    create_table :tenants, id: :uuid, default: -> { "gen_random_uuid()" }, if_not_exists: true do |t|
      t.text :name, null: false
      t.text :slug, null: false
      t.text :document
      t.text :timezone, default: "America/Sao_Paulo", null: false
      t.uuid :plan_id
      t.enum :status, enum_type: "tenant_status", default: "trial", null: false
      t.text :stripe_customer_id
      t.text :stripe_subscription_id
      t.timestamptz :current_period_start
      t.timestamptz :current_period_end
      t.timestamptz :trial_ends_at
      t.timestamptz :created_at, default: -> { "now()" }, null: false
      t.timestamptz :updated_at, default: -> { "now()" }, null: false

      t.index [ :plan_id ], name: "index_tenants_on_plan_id"
      t.index [ :status ], name: "tenants_status_idx"
      t.unique_constraint [ :slug ], name: "tenants_slug_key"
      t.unique_constraint [ :stripe_customer_id ], name: "tenants_stripe_customer_id_key"
      t.unique_constraint [ :stripe_subscription_id ], name: "tenants_stripe_subscription_id_key"
    end

    unless foreign_key_exists?(:tenants, :plans)
      add_foreign_key :tenants, :plans, name: "tenants_plan_id_fkey"
    end
  end
end
