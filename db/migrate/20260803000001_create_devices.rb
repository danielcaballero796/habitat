class CreateDevices < ActiveRecord::Migration[7.1]
  def change
    create_table :devices do |t|
      # Core identity
      t.string :name, null: false
      t.string :type, null: false

      # Device metadata
      t.string :brand
      t.string :model
      t.string :room
      t.string :status

      # Connection info
      t.string :ip_address
      t.string :mac_address

      # Firmware
      t.string :firmware_version

      # Lifecycle
      t.date :purchase_date
      t.text :notes

      t.timestamps
    end

    add_index :devices, :type
    add_index :devices, :name
    add_index :devices, :room
  end
end
