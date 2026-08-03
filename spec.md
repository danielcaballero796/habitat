# Specs: Device Model and EAV-lite Attributes

**Change ID**: `2026-08-03-device-foundation`  
**Status**: Spec  
**Created**: 2026-08-03

This document defines the behavioral requirements for the Device and DeviceAttribute models. Each scenario uses Given/When/Then format and is directly testable via RSpec.

---

## Capability 1: Device Creation and Core Fields

A Device can be created with a name, type, and optional brand/model/room/status/IP/MAC/firmware/purchase_date/notes.

### Scenario 1.1: Create a Device with required fields only

```gherkin
Given no devices exist
When a Device is created with:
  | Field | Value           |
  | name  | "Living Room"   |
  | type  | :smart_plug     |
Then the Device is saved successfully
And the Device has:
  | Field | Value           |
  | name  | "Living Room"   |
  | type  | :smart_plug     |
And the Device has an id
And the Device's created_at is set
```

**Why this test?** Validates that Device#create works with the minimum required fields. Rails should auto-populate id and timestamps.

**RSpec equivalent**:
```ruby
device = Device.create(name: "Living Room", type: :smart_plug)
expect(device).to be_persisted
expect(device.name).to eq "Living Room"
expect(device.type).to eq "smart_plug" # enum stored as string
expect(device.id).to be_present
expect(device.created_at).to be_present
```

---

### Scenario 1.2: Create a Device with all optional fields

```gherkin
Given no devices exist
When a Device is created with:
  | Field              | Value                        |
  | name               | "Tapo Plug 1"                |
  | type               | :smart_plug                  |
  | brand              | "TP-Link"                    |
  | model              | "Tapo P115"                  |
  | room               | "Kitchen"                    |
  | status             | "online"                     |
  | ip_address         | "192.168.1.100"              |
  | mac_address        | "AA:BB:CC:DD:EE:FF"          |
  | firmware_version   | "1.2.4"                      |
  | purchase_date      | 2024-01-15                   |
  | notes              | "Energy monitoring enabled"  |
Then the Device is saved successfully
And all fields are stored correctly
```

**Why this test?** Validates that all optional fields can be stored and retrieved. This tests the full schema without triggering validations that aren't required yet.

---

### Scenario 1.3: Attempt to create a Device without a name

```gherkin
Given no devices exist
When a Device is created with:
  | Field | Value       |
  | type  | :smart_plug |
Then the Device is NOT saved
And Device.all is empty
And the Device has a validation error on :name
And the error message includes "can't be blank"
```

**Why this test?** Validates that name is required. Rails should reject the save and populate errors.

**RSpec equivalent**:
```ruby
device = Device.new(type: :smart_plug)
expect(device.save).to be false
expect(device.errors[:name]).to include "can't be blank"
```

---

### Scenario 1.4: Attempt to create a Device without a type

```gherkin
Given no devices exist
When a Device is created with:
  | Field | Value         |
  | name  | "Living Room" |
Then the Device is NOT saved
And Device.all is empty
And the Device has a validation error on :type
And the error message includes "can't be blank"
```

**Why this test?** Validates that type is required.

---

### Scenario 1.5: Attempt to create a Device with an invalid type

```gherkin
Given no devices exist
When a Device is created with:
  | Field | Value           |
  | name  | "My Device"     |
  | type  | :invalid_type   |
Then the Device is NOT saved
And the Device has a validation error on :type
And the error message includes "invalid" or "unknown"
```

**Why this test?** The enum is closed. Types outside (smart_plug, led_controller, binary_sensor, relay, power_strip, hub, zigbee_dongle) should be rejected.

**RSpec equivalent**:
```ruby
device = Device.new(name: "My Device", type: :invalid_type)
expect(device.save).to be false
expect(device.errors[:type]).not_to be_empty
```

---

## Capability 2: Device Attributes (Key-Value Storage)

A Device can have zero or more attributes. Each attribute is a key-value pair stored in the DeviceAttribute table.

### Scenario 2.1: Create a Device with no attributes

```gherkin
Given no devices exist
When a Device is created with:
  | Field | Value           |
  | name  | "Hub"           |
  | type  | :hub            |
Then the Device is saved
And device.device_attributes is empty
And device.device_attributes.count == 0
```

**Why this test?** Attributes are optional. A Device with zero attributes is valid.

---

### Scenario 2.2: Add an attribute to an existing Device

```gherkin
Given a Device exists with name "Tapo Plug" and type :smart_plug
When an attribute is added with:
  | Field | Value        |
  | key   | "power_w"    |
  | value | "12.5"       |
Then the attribute is saved
And device.device_attributes.count == 1
And the attribute can be retrieved via device.device_attributes
And the attribute's device_id equals the Device's id
```

**Why this test?** Validates the has_many association works and attributes are properly indexed by device_id.

**RSpec equivalent**:
```ruby
device = Device.create!(name: "Tapo Plug", type: :smart_plug)
attr = device.device_attributes.create!(key: "power_w", value: "12.5")
expect(device.device_attributes.count).to eq 1
expect(device.device_attributes.first.key).to eq "power_w"
expect(attr.device_id).to eq device.id
```

---

### Scenario 2.3: Add multiple attributes to a Device

```gherkin
Given a Device exists with name "Tapo Plug" and type :smart_plug
When attributes are added:
  | key              | value      |
  | power_w          | 12.5       |
  | voltage_v        | 230        |
  | current_ma       | 54.3       |
Then the Device now has 3 attributes
And each attribute can be retrieved via device.device_attributes
And attribute with key "power_w" has value "12.5"
And attribute with key "voltage_v" has value "230"
And attribute with key "current_ma" has value "54.3"
```

**Why this test?** Validates that multiple attributes can coexist and be retrieved correctly.

---

### Scenario 2.4: Attempt to create an attribute without a key

```gherkin
Given a Device exists with name "Tapo Plug" and type :smart_plug
When an attribute is created with:
  | Field | Value  |
  | value | "12.5" |
Then the attribute is NOT saved
And device.device_attributes.count == 0
And the attribute has a validation error on :key
And the error message includes "can't be blank"
```

**Why this test?** Validates that key is required. Every attribute must have a key.

**RSpec equivalent**:
```ruby
device = Device.create!(name: "Tapo Plug", type: :smart_plug)
attr = device.device_attributes.build(value: "12.5")
expect(attr.save).to be false
expect(attr.errors[:key]).to include "can't be blank"
expect(device.device_attributes.count).to eq 0
```

---

### Scenario 2.5: Delete a Device cascades to delete its attributes

```gherkin
Given a Device exists with name "Tapo Plug" and type :smart_plug
And the Device has 2 attributes (power_w: 12.5, voltage_v: 230)
When the Device is deleted
Then the Device no longer exists
And the 2 attributes no longer exist
And DeviceAttribute.count == 0
```

**Why this test?** Validates Rails dependent: :destroy behavior. When a Device is deleted, its attributes are cleaned up automatically (no orphaned records).

**RSpec equivalent**:
```ruby
device = Device.create!(name: "Tapo Plug", type: :smart_plug)
device.device_attributes.create!(key: "power_w", value: "12.5")
device.device_attributes.create!(key: "voltage_v", value: "230")
device_id = device.id
device.destroy
expect(Device.find_by(id: device_id)).to be_nil
expect(DeviceAttribute.where(device_id: device_id).count).to eq 0
```

---

### Scenario 2.6: Attempt to create a duplicate key for the same Device

```gherkin
Given a Device exists with name "Tapo Plug" and type :smart_plug
And the Device has an attribute with key "power_w" and value "12.5"
When an attribute is created with key "power_w" and value "13.0" (same key, different value)
Then the second attribute is NOT saved
And device.device_attributes.count == 1 (still only the first attribute)
And the second attribute has a validation error on :key
And the error message includes "already exists" or "taken"
```

**Why this test?** Key must be unique per device (scoped uniqueness). We want current state, not history. Each key can exist at most once per device.

**RSpec equivalent**:
```ruby
device = Device.create!(name: "Tapo Plug", type: :smart_plug)
device.device_attributes.create!(key: "power_w", value: "12.5")
attr2 = device.device_attributes.build(key: "power_w", value: "13.0")
expect(attr2.save).to be false
expect(attr2.errors[:key]).not_to be_empty
expect(device.device_attributes.count).to eq 1
```

---

### Scenario 2.7: Attempt to create an attribute with a blank value

```gherkin
Given a Device exists with name "Tapo Plug" and type :smart_plug
When an attribute is created with key "power_w" and value "" (empty string)
Then the attribute is NOT saved
And device.device_attributes.count == 0
And the attribute has a validation error on :value
And the error message includes "can't be blank"
```

**Why this test?** Attribute values must be present/non-blank. An empty value is meaningless and should be rejected.

**RSpec equivalent**:
```ruby
device = Device.create!(name: "Tapo Plug", type: :smart_plug)
attr = device.device_attributes.build(key: "power_w", value: "")
expect(attr.save).to be false
expect(attr.errors[:value]).to include "can't be blank"
```

---

## Capability 3: Device Validation and Constraints

The Device model enforces type safety and prevents invalid state.

### Scenario 3.1: Rails enum validation for :type

```gherkin
Given a Device with type :smart_plug
When the type is assigned an invalid value (e.g., :nonexistent_type)
Then the assignment raises an error (or the save fails with a validation error)
```

**Why this test?** Rails enums validate at the model level. Invalid enum values should be rejected.

**RSpec equivalent**:
```ruby
device = Device.new(name: "Test", type: :smart_plug)
expect { device.type = :invalid }.to raise_error(ArgumentError) 
# OR
device = Device.new(name: "Test", type: :invalid)
expect(device.valid?).to be false
```

---

### Scenario 3.2: Type values are stored in the database as strings

```gherkin
Given a Device with name "Tapo Plug" and type :smart_plug
When the Device is saved and reloaded from the database
Then device.type == :smart_plug (Ruby symbol comparison)
And the raw SQL shows the column value as "smart_plug" (string)
```

**Why this test?** Rails enums store as strings in the database but expose as symbols in Ruby code. This test validates that behavior.

**RSpec equivalent**:
```ruby
device = Device.create!(name: "Tapo Plug", type: :smart_plug)
reloaded = Device.find(device.id)
expect(reloaded.type).to eq :smart_plug
expect(reloaded.read_attribute_before_type_cast(:type)).to eq "smart_plug"
```

---

### Scenario 3.3: Timestamp fields are auto-populated

```gherkin
Given a Device is created
When the Device is saved
Then created_at is set to the current time (within 1 second)
And updated_at is set to the current time (within 1 second)
And updated_at == created_at (initially)
```

**Why this test?** Rails automatically manages created_at and updated_at. Verify they're present and correct.

---

### Scenario 3.4: Updating a Device changes updated_at but not created_at

```gherkin
Given a Device was created 1 minute ago
When the Device is updated (e.g., name changed)
Then created_at remains unchanged
And updated_at is now (current time)
And updated_at > created_at (by ~1 minute)
```

**Why this test?** Validates Rails timestamp behavior during updates.

**RSpec equivalent**:
```ruby
device = Device.create!(name: "Old Name", type: :smart_plug)
original_created_at = device.created_at
sleep 0.1
device.update(name: "New Name")
expect(device.created_at).to eq original_created_at
expect(device.updated_at).to be > original_created_at
```

---

## Capability 4: Model Association Behavior

Device and DeviceAttribute maintain a proper Rails association.

### Scenario 4.1: Association method device_attributes returns a collection

```gherkin
Given a Device with 2 attributes
When device.device_attributes is called
Then the return value is a collection (Array-like)
And the collection responds to .count, .each, .first, .create!, etc.
And the collection includes all 2 attributes
```

**Why this test?** Validates that has_many association works correctly.

---

### Scenario 4.2: Association method device returns the parent Device

```gherkin
Given a DeviceAttribute belonging to a Device
When attribute.device is called
Then the return value is the parent Device
And attribute.device_id == device.id
```

**Why this test?** Validates belongs_to association.

**RSpec equivalent**:
```ruby
device = Device.create!(name: "Tapo Plug", type: :smart_plug)
attr = device.device_attributes.create!(key: "power_w", value: "12.5")
expect(attr.device).to eq device
expect(attr.device.id).to eq device.id
```

---

### Scenario 4.3: Find an attribute by key within a Device

```gherkin
Given a Device exists with name "Tapo Plug" and type :smart_plug
And the Device has attributes:
  | key              | value      |
  | power_w          | 12.5       |
  | voltage_v        | 230        |
  | current_ma       | 54.3       |
When device.device_attributes.find_by(key: "power_w") is called
Then the result is the attribute with key "power_w" and value "12.5"
And the result is NOT nil
```

**Why this test?** Real-world use case: dashboards need to retrieve a specific attribute by key (e.g., "what's the current power draw?"). Rails find_by works on associations.

**RSpec equivalent**:
```ruby
device = Device.create!(name: "Tapo Plug", type: :smart_plug)
device.device_attributes.create!(key: "power_w", value: "12.5")
device.device_attributes.create!(key: "voltage_v", value: "230")
device.device_attributes.create!(key: "current_ma", value: "54.3")
result = device.device_attributes.find_by(key: "power_w")
expect(result).not_to be_nil
expect(result.key).to eq "power_w"
expect(result.value).to eq "12.5"
```

---

## Summary: Spec Scenarios

| Capability | Scenario Count | Key Tests |
|------------|---|---|
| Device Creation | 5 | Required fields, optional fields, missing name/type, invalid type |
| Device Attributes | 7 | Zero attributes, add one/multiple, missing key, blank value, duplicate keys, cascade delete |
| Validation | 4 | Enum validation, type storage, timestamps, update behavior |
| Associations | 3 | has_many and belongs_to, find_by key |
| **Total** | **19 scenarios** | **19 RSpec test cases** |

---

## How These Specs Drive Implementation

Each scenario will become a test case in the apply phase:
- Scenarios 1.1–1.5 → `spec/models/device_spec.rb` (Device creation and validation)
- Scenarios 2.1–2.5 → `spec/models/device_spec.rb` (Device attributes via association)
- Scenarios 3.1–3.4 → `spec/models/device_spec.rb` (Validation behavior)
- Scenarios 4.1–4.2 → `spec/models/device_attribute_spec.rb` (Association behavior)

In the apply phase, we'll write the RSpec tests first (RED), then write the Rails code to make them pass (GREEN).

---

## Questions Before Proceeding to Design

1. Are all 16 scenarios clear? Do you see any missing test cases?
2. Should we add a scenario for attributes with empty string values (allowed or not)?
3. Should we add a scenario for duplicate keys within the same device (allowed or not)?

