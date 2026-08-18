class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles, if_not_exists: true do |t|
      ## Devise database_authenticatable
      t.string :email, null: false, default: ""
      t.string :encrypted_password, null: false, default: ""

      ## Devise recoverable
      t.string :reset_password_token
      t.datetime :reset_password_sent_at

      ## Devise rememberable
      t.datetime :remember_created_at

      ## Devise trackable
      t.integer :sign_in_count, null: false, default: 0
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string :current_sign_in_ip
      t.string :last_sign_in_ip

      ## Tenant/role
      t.references :tenant, foreign_key: true, index: true
      t.string :role, null: false, default: "agent"

      t.timestamps
    end

    add_index :profiles, :email, unique: true, if_not_exists: true
    add_index :profiles, :reset_password_token, unique: true, if_not_exists: true

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
