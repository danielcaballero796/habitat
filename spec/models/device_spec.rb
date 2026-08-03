require "rails_helper"

RSpec.describe Device, type: :model do
  # ===== Capability 1: Device Creation (Scenarios 1.1-1.5) =====

  describe "creation with required fields only" do
    it "creates a Device with name and type" do
      device = Device.create(name: "Living Room", type: :smart_plug)
      expect(device).to be_persisted
      expect(device.name).to eq "Living Room"
      expect(device.type).to eq :smart_plug
      expect(device.id).to be_present
      expect(device.created_at).to be_present
    end
  end

  describe "creation with all fields" do
    it "stores all fields correctly" do
      device = Device.create(
        name: "Tapo Plug 1",
        type: :smart_plug,
        brand: "TP-Link",
        model: "Tapo P115",
        room: "Kitchen",
        status: "online",
        ip_address: "192.168.1.100",
        mac_address: "AA:BB:CC:DD:EE:FF",
        firmware_version: "1.2.4",
        purchase_date: Date.parse("2024-01-15"),
        notes: "Energy monitoring enabled"
      )
      expect(device).to be_persisted
      expect(device.brand).to eq "TP-Link"
      expect(device.notes).to eq "Energy monitoring enabled"
    end
  end

  describe "name validation" do
    it "requires a name (Scenario 1.3)" do
      device = Device.new(type: :smart_plug)
      expect(device.save).to be false
      expect(device.errors[:name]).to include "can't be blank"
      expect(Device.all.count).to eq 0
    end
  end

  describe "type validation" do
    it "requires a type (Scenario 1.4)" do
      device = Device.new(name: "Living Room")
      expect(device.save).to be false
      expect(device.errors[:type]).to include "can't be blank"
    end

    it "rejects invalid type enum values (Scenario 1.5)" do
      device = Device.new(name: "Test", type: :invalid_type)
      expect(device.save).to be false
      expect(device.errors[:type]).not_to be_empty
    end
  end

  # ===== Capability 2: Device Attributes (Scenarios 2.1-2.7) =====

  describe "attributes association" do
    it "device with no attributes is valid (Scenario 2.1)" do
      device = Device.create!(name: "Hub", type: :hub)
      expect(device.device_attributes.count).to eq 0
    end

    it "can add a single attribute (Scenario 2.2)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      attr = device.device_attributes.create!(key: "power_w", value: "12.5")
      expect(device.device_attributes.count).to eq 1
      expect(device.device_attributes.first.key).to eq "power_w"
      expect(attr.device_id).to eq device.id
    end

    it "can add multiple attributes (Scenario 2.3)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      device.device_attributes.create!(key: "power_w", value: "12.5")
      device.device_attributes.create!(key: "voltage_v", value: "230")
      device.device_attributes.create!(key: "current_ma", value: "54.3")
      expect(device.device_attributes.count).to eq 3
      expect(device.device_attributes.find_by(key: "power_w").value).to eq "12.5"
    end

    it "cascades delete on device destruction (Scenario 2.5)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      device.device_attributes.create!(key: "power_w", value: "12.5")
      device.device_attributes.create!(key: "voltage_v", value: "230")
      device_id = device.id
      device.destroy
      expect(Device.find_by(id: device_id)).to be_nil
      expect(DeviceAttribute.where(device_id: device_id).count).to eq 0
    end

    it "finds attribute by key (Scenario 4.3)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      device.device_attributes.create!(key: "power_w", value: "12.5")
      device.device_attributes.create!(key: "voltage_v", value: "230")
      result = device.device_attributes.find_by(key: "power_w")
      expect(result).not_to be_nil
      expect(result.value).to eq "12.5"
    end
  end

  # ===== Capability 3: Validation & Timestamps (Scenarios 3.3-3.4) =====

  describe "timestamps" do
    it "auto-populates created_at and updated_at (Scenario 3.3)" do
      device = Device.create!(name: "Test", type: :smart_plug)
      expect(device.created_at).to be_present
      expect(device.updated_at).to be_present
      expect((device.updated_at - device.created_at).abs).to be < 1
    end

    it "updates updated_at on update but not created_at (Scenario 3.4)" do
      device = Device.create!(name: "Old Name", type: :smart_plug)
      original_created_at = device.created_at
      sleep 0.1
      device.update(name: "New Name")
      expect(device.created_at).to eq original_created_at
      expect(device.updated_at).to be > original_created_at
    end
  end

  # ===== Capability 4: Associations (Scenario 4.1) =====

  describe "device_attributes association" do
    it "returns a collection with expected methods (Scenario 4.1)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      device.device_attributes.create!(key: "power_w", value: "12.5")
      device.device_attributes.create!(key: "voltage_v", value: "230")

      attrs = device.device_attributes
      expect(attrs).to respond_to(:count)
      expect(attrs).to respond_to(:each)
      expect(attrs).to respond_to(:first)
      expect(attrs).to respond_to(:create!)
      expect(attrs.count).to eq 2
    end
  end
end
