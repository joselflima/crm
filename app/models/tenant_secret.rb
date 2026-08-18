class TenantSecret < ApplicationRecord
  belongs_to :tenant

  encrypts :whatsapp_access_token
  encrypts :instagram_access_token
end
