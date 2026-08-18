class CreateChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :channels, if_not_exists: true do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :type, null: false
      t.string :external_id, null: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :channels, [ :type, :external_id ], unique: true, if_not_exists: true
  end
end
