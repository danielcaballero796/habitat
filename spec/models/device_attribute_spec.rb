require "rails_helper"

RSpec.describe DeviceAttribute, type: :model do
  # ===== Capability 2: Device Attributes Validation (Scenarios 2.4, 2.6, 2.7) =====

  describe "validations" do
    it "requires a key (Scenario 2.4)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      attr = device.device_attributes.build(value: "12.5")
      expect(attr.save).to be false
      expect(attr.errors[:key]).to include "can't be blank"
      expect(device.device_attributes.count).to eq 0
    end

    it "requires a value (Scenario 2.7)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      attr = device.device_attributes.build(key: "power_w", value: "")
      expect(attr.save).to be false
      expect(attr.errors[:value]).to include "can't be blank"
    end

    it "enforces uniqueness of key per device (Scenario 2.6)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      device.device_attributes.create!(key: "power_w", value: "12.5")
      attr2 = device.device_attributes.build(key: "power_w", value: "13.0")
      expect(attr2.save).to be false
      expect(attr2.errors[:key]).not_to be_empty
      expect(device.device_attributes.count).to eq 1
    end
  end

  # ===== Capability 4: Associations (Scenario 4.2) =====

  describe "device association" do
    it "belongs to a device and returns parent (Scenario 4.2)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      attr = device.device_attributes.create!(key: "power_w", value: "12.5")
      expect(attr.device).to eq device
      expect(attr.device.id).to eq device.id
    end
  end

  # ===== Capability 3: Enum Type Storage (Scenario 3.1-3.2) =====

  describe "type enum storage" do
    it "stores type as string in DB, symbol in Ruby (Scenario 3.2)" do
      device = Device.create!(name: "Test", type: :smart_plug)
      reloaded = Device.find(device.id)
      expect(reloaded.type.to_sym).to eq :smart_plug  # Rails enum comparison
      expect(reloaded.read_attribute_before_type_cast(:type)).to eq "smart_plug"
    end
  end
end
