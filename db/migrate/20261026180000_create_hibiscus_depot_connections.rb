class CreateHibiscusDepotConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :hibiscus_depot_connections, id: :uuid do |t|
      t.references :family, type: :uuid, null: false, foreign_key: true
      t.string :hibiscus_account_id, null: false
      t.jsonb :raw_payload, null: false, default: {}
      t.datetime :last_imported_at
      t.timestamps
    end
    add_index :hibiscus_depot_connections, [ :family_id, :hibiscus_account_id ], unique: true, name: "idx_hibiscus_depot_family_source"
  end
end
