class CreateChannels < ActiveRecord::Migration[8.1]
  # Mirrors the real, already-deployed `channels` table (see CreatePlans for
  # why these migrations are written defensively). `type` is the provider
  # column, not a Rails STI discriminator.
  def change
    create_enum :channel_type, %w[whatsapp instagram]
    create_enum :channel_status, %w[pending connected error disabled]

    create_table :channels, id: :uuid, default: -> { "gen_random_uuid()" }, if_not_exists: true do |t|
      t.uuid :tenant_id, null: false
      t.enum :type, enum_type: "channel_type", null: false
      t.text :external_id, null: false
      t.text :display_name, null: false
      t.enum :status, enum_type: "channel_status", default: "pending", null: false
      t.text :access_token
      t.text :phone_number
      t.text :waba_id
      t.text :page_id
      t.text :last_error
      t.timestamptz :webhook_verified_at
      t.timestamptz :created_at, default: -> { "now()" }, null: false
      t.timestamptz :updated_at, default: -> { "now()" }, null: false

      t.index [ :tenant_id ], name: "index_channels_on_tenant_id"
      t.index [ :tenant_id ], name: "channels_tenant_idx", where: "(status = 'connected'::channel_status)"
      t.index [ :type, :external_id ], name: "index_channels_on_type_and_external_id", unique: true
      t.unique_constraint [ :type, :external_id ], name: "channels_type_external_unique"
    end

    unless foreign_key_exists?(:channels, :tenants)
      add_foreign_key :channels, :tenants, name: "channels_tenant_id_fkey", on_delete: :cascade
    end
  end
end
