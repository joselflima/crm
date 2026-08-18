class CreateTenantSecrets < ActiveRecord::Migration[8.1]
  def change
    create_table :tenant_secrets, if_not_exists: true do |t|
      t.references :tenant, null: false, foreign_key: true, index: { unique: true }

      # Encrypted at the application layer (ActiveRecord::Encryption) —
      # never readable via a plain `select *` from a non-privileged role.
      t.text :whatsapp_access_token
      t.string :whatsapp_phone_number_id
      t.text :instagram_access_token
      t.string :instagram_business_account_id

      t.timestamps
    end
  end
end
