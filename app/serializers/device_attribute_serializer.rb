class DeviceAttributeSerializer < ActiveModel::Serializer
  attributes :id, :key, :value, :created_at, :updated_at
end
