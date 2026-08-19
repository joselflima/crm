# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_18_214506) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

  # Custom types defined in this database.
  # Note that some types may not work with other database engines. Be careful if changing database.
  create_enum "channel_status", ["pending", "connected", "error", "disabled"]
  create_enum "channel_type", ["whatsapp", "instagram"]
  create_enum "conversation_status", ["bot", "queued", "assigned", "closed"]
  create_enum "message_direction", ["inbound", "outbound"]
  create_enum "message_status", ["pending", "sent", "delivered", "read", "failed"]
  create_enum "sender_type", ["contact", "ai", "agent", "system"]
  create_enum "tenant_status", ["trial", "active", "past_due", "suspended", "canceled"]
  create_enum "user_role", ["super_admin", "admin", "agent"]

  create_table "channels", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "access_token"
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.text "display_name", null: false
    t.text "external_id", null: false
    t.text "last_error"
    t.text "page_id"
    t.text "phone_number"
    t.enum "status", default: "pending", null: false, enum_type: "channel_status"
    t.uuid "tenant_id", null: false
    t.enum "type", null: false, enum_type: "channel_type"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.text "waba_id"
    t.timestamptz "webhook_verified_at"
    t.index ["tenant_id"], name: "channels_tenant_idx", where: "(status = 'connected'::channel_status)"
    t.index ["tenant_id"], name: "index_channels_on_tenant_id"
    t.index ["type", "external_id"], name: "index_channels_on_type_and_external_id", unique: true
    t.unique_constraint ["type", "external_id"], name: "channels_type_external_unique"
  end

  create_table "contacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "avatar_url"
    t.uuid "channel_id", null: false
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.jsonb "custom_fields", default: {}, null: false
    t.text "email"
    t.text "external_user_id", null: false
    t.timestamptz "first_seen_at", default: -> { "now()" }, null: false
    t.boolean "is_blocked", default: false, null: false
    t.timestamptz "last_message_at"
    t.text "name"
    t.text "notes"
    t.text "phone"
    t.text "tags", default: [], null: false, array: true
    t.uuid "tenant_id", null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.index ["tenant_id", "last_message_at"], name: "contacts_tenant_last_msg_idx", order: { last_message_at: :desc }
    t.unique_constraint ["tenant_id", "channel_id", "external_user_id"], name: "contacts_tenant_channel_external_unique"
  end

  create_table "conversations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "ai_paused", default: false, null: false
    t.integer "ai_turn_count", default: 0, null: false
    t.timestamptz "assigned_at"
    t.uuid "assigned_to"
    t.timestamptz "billing_window_started_at"
    t.uuid "channel_id", null: false
    t.timestamptz "closed_at"
    t.uuid "contact_id", null: false
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.text "handoff_reason"
    t.timestamptz "last_inbound_at"
    t.timestamptz "last_message_at"
    t.timestamptz "last_outbound_at"
    t.timestamptz "service_window_expires_at"
    t.enum "status", default: "bot", null: false, enum_type: "conversation_status"
    t.text "summary"
    t.uuid "tenant_id", null: false
    t.integer "unread_count", default: 0, null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.index ["contact_id"], name: "conversations_one_open_per_contact", unique: true, where: "(status <> 'closed'::conversation_status)"
    t.index ["tenant_id", "assigned_to", "status"], name: "conversations_tenant_assigned_idx"
    t.index ["tenant_id", "status", "last_message_at"], name: "conversations_tenant_status_idx", order: { last_message_at: :desc }
  end

  create_table "messages", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "content"
    t.text "content_type", default: "text", null: false
    t.uuid "conversation_id", null: false
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.timestamptz "delivered_at"
    t.enum "direction", null: false, enum_type: "message_direction"
    t.text "error_code"
    t.text "error_message"
    t.text "media_mime"
    t.bigint "media_size_bytes"
    t.text "media_url"
    t.jsonb "metadata", default: {}, null: false
    t.text "provider_message_id"
    t.timestamptz "read_at"
    t.uuid "reply_to_id"
    t.uuid "sender_id"
    t.enum "sender_type", null: false, enum_type: "sender_type"
    t.enum "status", default: "sent", null: false, enum_type: "message_status"
    t.uuid "tenant_id", null: false
    t.index ["conversation_id", "created_at"], name: "messages_conversation_idx", order: { created_at: :desc }
    t.index ["tenant_id", "created_at"], name: "messages_tenant_idx", order: { created_at: :desc }
    t.index ["tenant_id", "provider_message_id"], name: "messages_provider_unique", unique: true, where: "(provider_message_id IS NOT NULL)"
  end

  create_table "notifications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "body"
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.text "link"
    t.timestamptz "read_at"
    t.text "severity", default: "info", null: false
    t.uuid "tenant_id", null: false
    t.text "title", null: false
    t.text "type", null: false
    t.uuid "user_id"
    t.index ["tenant_id", "user_id", "read_at"], name: "notifications_tenant_user_idx"
  end

  create_table "plans", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "allow_byok", default: false, null: false
    t.text "code", null: false
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.text "currency", default: "BRL", null: false
    t.jsonb "features", default: {}, null: false
    t.integer "included_conversations", default: 500, null: false
    t.boolean "is_active", default: true, null: false
    t.integer "max_channels", default: 1, null: false
    t.integer "max_users", default: 3, null: false
    t.text "name", null: false
    t.integer "overage_pack_price_cents", default: 19700, null: false
    t.integer "overage_pack_size", default: 500, null: false
    t.integer "price_cents", default: 0, null: false
    t.integer "sort_order", default: 0, null: false

    t.unique_constraint ["code"], name: "plans_code_key"
  end

  create_table "profiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "avatar_url"
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.text "email", null: false
    t.text "full_name"
    t.boolean "is_active", default: true, null: false
    t.timestamptz "last_seen_at"
    t.text "password_hash"
    t.text "phone"
    t.enum "role", default: "agent", null: false, enum_type: "user_role"
    t.uuid "tenant_id"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.index "lower(email)", name: "profiles_email_unique", unique: true
    t.index ["email"], name: "index_profiles_on_email", unique: true
    t.index ["tenant_id"], name: "index_profiles_on_tenant_id"
    t.check_constraint "role = 'super_admin'::user_role AND tenant_id IS NULL OR role <> 'super_admin'::user_role AND tenant_id IS NOT NULL", name: "profiles_super_admin_tenant_check"
    t.check_constraint "role = 'super_admin'::user_role AND tenant_id IS NULL OR role <> 'super_admin'::user_role AND tenant_id IS NOT NULL", name: "profiles_tenant_required"
  end

  create_table "tenant_secrets", primary_key: "tenant_id", id: :uuid, default: nil, force: :cascade do |t|
    t.text "anthropic_api_key"
    t.text "instagram_access_token"
    t.text "instagram_business_account_id"
    t.text "meta_access_token"
    t.text "meta_app_secret"
    t.text "openai_api_key"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.text "whatsapp_access_token"
    t.text "whatsapp_phone_number_id"
    t.index ["tenant_id"], name: "index_tenant_secrets_on_tenant_id", unique: true
  end

  create_table "tenant_settings", primary_key: "tenant_id", id: :uuid, default: nil, force: :cascade do |t|
    t.boolean "ai_enabled", default: true, null: false
    t.integer "ai_max_output_tokens", default: 600, null: false
    t.text "ai_model", default: "claude-haiku-4-5-20251001", null: false
    t.text "ai_provider", default: "anthropic", null: false
    t.decimal "ai_temperature", precision: 3, scale: 2, default: "0.3", null: false
    t.boolean "auto_assign_enabled", default: false, null: false
    t.jsonb "business_hours", default: {}, null: false
    t.text "handoff_message", default: "Só um momento, vou chamar um atendente para você.", null: false
    t.integer "max_ai_turns", default: 20, null: false
    t.text "offline_message"
    t.text "out_of_credits_message", default: "Recebi sua mensagem! Um atendente vai responder em instantes.", null: false
    t.boolean "respect_business_hours", default: false, null: false
    t.integer "response_delay_seconds", default: 3, null: false
    t.text "system_prompt", default: "", null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
  end

  create_table "tenants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.timestamptz "current_period_end"
    t.timestamptz "current_period_start"
    t.text "document"
    t.text "name", null: false
    t.uuid "plan_id"
    t.text "slug", null: false
    t.enum "status", default: "trial", null: false, enum_type: "tenant_status"
    t.text "stripe_customer_id"
    t.text "stripe_subscription_id"
    t.text "timezone", default: "America/Sao_Paulo", null: false
    t.timestamptz "trial_ends_at"
    t.timestamptz "updated_at", default: -> { "now()" }, null: false
    t.index ["plan_id"], name: "index_tenants_on_plan_id"
    t.index ["status"], name: "tenants_status_idx"
    t.unique_constraint ["slug"], name: "tenants_slug_key"
    t.unique_constraint ["stripe_customer_id"], name: "tenants_stripe_customer_id_key"
    t.unique_constraint ["stripe_subscription_id"], name: "tenants_stripe_subscription_id_key"
  end

  create_table "webhook_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "attempts", default: 0, null: false
    t.text "channel_external_id"
    t.text "error"
    t.text "external_event_id", null: false
    t.jsonb "payload", null: false
    t.timestamptz "processed_at"
    t.text "provider", default: "meta", null: false
    t.timestamptz "received_at", default: -> { "now()" }, null: false
    t.text "status", default: "received", null: false
    t.uuid "tenant_id"

    t.unique_constraint ["provider", "external_event_id"], name: "webhook_events_provider_event_unique"
  end

  add_foreign_key "channels", "tenants", name: "channels_tenant_id_fkey", on_delete: :cascade
  add_foreign_key "contacts", "channels", name: "contacts_channel_id_fkey", on_delete: :cascade
  add_foreign_key "contacts", "tenants", name: "contacts_tenant_id_fkey", on_delete: :cascade
  add_foreign_key "conversations", "channels", name: "conversations_channel_id_fkey", on_delete: :cascade
  add_foreign_key "conversations", "contacts", name: "conversations_contact_id_fkey", on_delete: :cascade
  add_foreign_key "conversations", "profiles", column: "assigned_to", name: "conversations_assigned_to_fkey", on_delete: :nullify
  add_foreign_key "conversations", "tenants", name: "conversations_tenant_id_fkey", on_delete: :cascade
  add_foreign_key "messages", "conversations", name: "messages_conversation_id_fkey", on_delete: :cascade
  add_foreign_key "messages", "messages", column: "reply_to_id", name: "messages_reply_to_id_fkey", on_delete: :nullify
  add_foreign_key "messages", "profiles", column: "sender_id", name: "messages_sender_id_fkey", on_delete: :nullify
  add_foreign_key "messages", "tenants", name: "messages_tenant_id_fkey", on_delete: :cascade
  add_foreign_key "notifications", "profiles", column: "user_id", name: "notifications_user_id_fkey", on_delete: :cascade
  add_foreign_key "notifications", "tenants", name: "notifications_tenant_id_fkey", on_delete: :cascade
  add_foreign_key "profiles", "tenants", name: "profiles_tenant_id_fkey", on_delete: :cascade
  add_foreign_key "tenant_secrets", "tenants", name: "tenant_secrets_tenant_id_fkey", on_delete: :cascade
  add_foreign_key "tenant_settings", "tenants", name: "tenant_settings_tenant_id_fkey", on_delete: :cascade
  add_foreign_key "tenants", "plans", name: "tenants_plan_id_fkey"
  add_foreign_key "webhook_events", "tenants", name: "webhook_events_tenant_id_fkey", on_delete: :nullify
end
