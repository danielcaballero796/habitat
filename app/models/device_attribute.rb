class DeviceAttribute < ApplicationRecord
  # Associations
  belongs_to :device

  # Validations
  validates :key, presence: true
  validates :value, presence: true
  validates :key, uniqueness: { scope: :device_id, message: "must be unique per device" }
end
