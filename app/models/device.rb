class Device < ApplicationRecord
  # Disable Single Table Inheritance since we're using :type as data, not for inheritance
  self.inheritance_column = :_type_id

  # Enum: closed list of device types
  enum :type, {
    smart_plug: "smart_plug",
    led_controller: "led_controller",
    binary_sensor: "binary_sensor",
    relay: "relay",
    power_strip: "power_strip",
    hub: "hub",
    zigbee_dongle: "zigbee_dongle"
  }

  # Associations
  has_many :device_attributes, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :type, presence: true
end
