class TenantSecret < ApplicationRecord
  # The table is keyed by tenant_id — there is no separate `id` column.
  self.primary_key = "tenant_id"

  belongs_to :tenant

  encrypts :whatsapp_access_token
  encrypts :instagram_access_token
end
