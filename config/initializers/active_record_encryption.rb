# TenantSecret#whatsapp_access_token / #instagram_access_token use
# ActiveRecord::Encryption (see app/models/tenant_secret.rb). Keys can come
# from Rails credentials (`bin/rails credentials:edit`, under
# active_record_encryption:) or from these ENV vars — useful for CI/test
# environments that don't have the app's master key.
if ENV["AR_ENCRYPTION_PRIMARY_KEY"].present?
  Rails.application.config.active_record.encryption.primary_key = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
  Rails.application.config.active_record.encryption.deterministic_key = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
  Rails.application.config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]
end
