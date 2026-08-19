class CreateTenantSecrets < ActiveRecord::Migration[8.1]
  # Mirrors the real, already-deployed `tenant_secrets` table: it is keyed by
  # tenant_id (no separate id) and carries only the generic provider keys.
  # The per-channel WhatsApp/Instagram credentials are added by
  # AddChannelCredentialsToTenantSecrets.
  def change
    create_table :tenant_secrets, primary_key: :tenant_id, id: :uuid, default: nil, if_not_exists: true do |t|
      # Encrypted at the application layer (ActiveRecord::Encryption) —
      # never readable via a plain `select *` from a non-privileged role.
      t.text :meta_access_token
      t.text :meta_app_secret
      t.text :openai_api_key
      t.text :anthropic_api_key
      t.timestamptz :updated_at, default: -> { "now()" }, null: false

      t.index [ :tenant_id ], name: "index_tenant_secrets_on_tenant_id", unique: true
    end

    unless foreign_key_exists?(:tenant_secrets, :tenants)
      add_foreign_key :tenant_secrets, :tenants, name: "tenant_secrets_tenant_id_fkey", on_delete: :cascade
    end
  end
end
