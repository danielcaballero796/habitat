class CreateDeviceAttributes < ActiveRecord::Migration[7.1]
  def change
    create_table :device_attributes do |t|
      t.references :device, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value, null: false

      t.timestamps
    end

    add_index :device_attributes, [:device_id, :key], unique: true
  end
end
