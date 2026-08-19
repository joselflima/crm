class CreateProfiles < ActiveRecord::Migration[8.1]
  # Mirrors the real, already-deployed `profiles` table (see CreatePlans for
  # why these migrations are written defensively). Devise reads
  # `password_hash` through an alias on the model — the column is not renamed.
  def change
    create_enum :user_role, %w[super_admin admin agent]

    create_table :profiles, id: :uuid, default: -> { "gen_random_uuid()" }, if_not_exists: true do |t|
      t.text :email, null: false
      t.text :password_hash
      t.text :full_name
      t.text :avatar_url
      t.text :phone
      t.boolean :is_active, default: true, null: false
      t.timestamptz :last_seen_at
      t.uuid :tenant_id
      t.enum :role, enum_type: "user_role", default: "agent", null: false
      t.timestamptz :created_at, default: -> { "now()" }, null: false
      t.timestamptz :updated_at, default: -> { "now()" }, null: false

      t.index "lower(email)", name: "profiles_email_unique", unique: true
      t.index [ :email ], name: "index_profiles_on_email", unique: true
      t.index [ :tenant_id ], name: "index_profiles_on_tenant_id"
      t.check_constraint "role = 'super_admin'::user_role AND tenant_id IS NULL OR " \
                         "role <> 'super_admin'::user_role AND tenant_id IS NOT NULL",
                         name: "profiles_tenant_required"
    end

    unless foreign_key_exists?(:profiles, :tenants)
      add_foreign_key :profiles, :tenants, name: "profiles_tenant_id_fkey", on_delete: :cascade
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          DO $$
          BEGIN
            IF NOT EXISTS (
              SELECT 1 FROM pg_constraint WHERE conname = 'profiles_super_admin_tenant_check'
            ) THEN
              ALTER TABLE profiles
              ADD CONSTRAINT profiles_super_admin_tenant_check
              CHECK (
                (role = 'super_admin' AND tenant_id IS NULL) OR
                (role <> 'super_admin' AND tenant_id IS NOT NULL)
              );
            END IF;
          END $$;
        SQL
      end

      dir.down do
        execute "ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_super_admin_tenant_check"
      end
    end
  end
end
