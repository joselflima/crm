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

ActiveRecord::Schema[8.1].define(version: 2026_08_18_214505) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "channels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "status", default: "active", null: false
    t.bigint "tenant_id", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_channels_on_tenant_id"
    t.index ["type", "external_id"], name: "index_channels_on_type_and_external_id", unique: true
  end

  create_table "plans", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "max_channels"
    t.integer "max_users"
    t.integer "monthly_conversation_quota"
    t.string "name", null: false
    t.integer "price_cents"
    t.string "stripe_price_id"
    t.datetime "updated_at", null: false
  end

  create_table "profiles", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "full_name"
    t.boolean "is_active", default: true, null: false
    t.datetime "last_seen_at"
    t.string "password_hash", default: "", null: false
    t.string "phone"
    t.string "role", default: "agent", null: false
    t.bigint "tenant_id"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_profiles_on_email", unique: true
    t.index ["tenant_id"], name: "index_profiles_on_tenant_id"
    t.check_constraint "role::text = 'super_admin'::text AND tenant_id IS NULL OR role::text <> 'super_admin'::text AND tenant_id IS NOT NULL", name: "profiles_super_admin_tenant_check"
  end

  create_table "tenant_secrets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "instagram_access_token"
    t.string "instagram_business_account_id"
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.text "whatsapp_access_token"
    t.string "whatsapp_phone_number_id"
    t.index ["tenant_id"], name: "index_tenant_secrets_on_tenant_id", unique: true
  end

  create_table "tenants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "plan_id"
    t.string "status", default: "trial", null: false
    t.string "stripe_customer_id"
    t.datetime "updated_at", null: false
    t.index ["plan_id"], name: "index_tenants_on_plan_id"
  end

  add_foreign_key "channels", "tenants"
  add_foreign_key "profiles", "tenants"
  add_foreign_key "tenant_secrets", "tenants"
  add_foreign_key "tenants", "plans"
end
