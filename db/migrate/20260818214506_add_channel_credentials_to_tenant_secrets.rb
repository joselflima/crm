class AddChannelCredentialsToTenantSecrets < ActiveRecord::Migration[8.1]
  # `create_table :tenant_secrets, if_not_exists: true` was a no-op against the
  # already-existing table, which only carries the generic meta/openai/anthropic
  # keys. Add the per-provider channel credential columns it is missing.
  COLUMNS = {
    whatsapp_access_token: :text,
    whatsapp_phone_number_id: :text,
    instagram_access_token: :text,
    instagram_business_account_id: :text
  }.freeze

  def change
    COLUMNS.each do |name, type|
      add_column :tenant_secrets, name, type, if_not_exists: true
    end
  end
end
