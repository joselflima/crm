class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles, if_not_exists: true do |t|
      t.string :email, null: false, default: ""
      t.string :password_hash, null: false, default: ""
      t.string :full_name
      t.string :avatar_url
      t.string :phone
      t.boolean :is_active, null: false, default: true
      t.datetime :last_seen_at

      t.references :tenant, foreign_key: true, index: true
      t.string :role, null: false, default: "agent"

      t.timestamps
    end

    # create_table is a no-op when the table already exists (e.g. the
    # already-loaded production schema), so add exactly whatever columns are
    # still missing rather than assuming the block above ran.
    add_column :profiles, :email, :string, null: false, default: "" unless column_exists?(:profiles, :email)
    add_column :profiles, :password_hash, :string, null: false, default: "" unless column_exists?(:profiles, :password_hash)
    add_column :profiles, :full_name, :string unless column_exists?(:profiles, :full_name)
    add_column :profiles, :avatar_url, :string unless column_exists?(:profiles, :avatar_url)
    add_column :profiles, :phone, :string unless column_exists?(:profiles, :phone)
    add_column :profiles, :is_active, :boolean, null: false, default: true unless column_exists?(:profiles, :is_active)
    add_column :profiles, :last_seen_at, :datetime unless column_exists?(:profiles, :last_seen_at)
    add_reference :profiles, :tenant, foreign_key: true, index: true unless column_exists?(:profiles, :tenant_id)
    add_column :profiles, :role, :string, null: false, default: "agent" unless column_exists?(:profiles, :role)

    add_index :profiles, :email, unique: true, if_not_exists: true

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
