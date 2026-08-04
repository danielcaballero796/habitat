class DeviceSerializer < ActiveModel::Serializer
  attributes :id, :name, :type, :brand, :model, :room, :status, :ip_address, :mac_address, :firmware_version, :purchase_date, :notes, :created_at, :updated_at

  has_many :device_attributes, serializer: DeviceAttributeSerializer
end
