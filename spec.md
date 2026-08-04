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

# Specs: API Foundation with Single-User JWT Auth

**Change ID**: `2026-08-03-api-foundation-with-auth`  
**Status**: Spec  
**Created**: 2026-08-03

This document defines behavioral requirements for the API, login endpoint, JWT auth middleware, and versioned CRUD endpoints. Each scenario uses Given/When/Then format and is directly testable via RSpec request specs.

---

## Capability 1: User Model and Login Endpoint

A User stores email and hashed password (using bcrypt), and a login endpoint validates credentials and returns a signed JWT token with 1-day expiry.

### Scenario 1.1: User can be created with email and password

```gherkin
Given no users exist
When a User is created with email "admin@habitat.local" and password "secure123"
Then the User is saved successfully
And the User's password_digest is NOT the plaintext password (bcrypt hash)
And the User's email is "admin@habitat.local"
```

**Why this test?** Validates User model with bcrypt password hashing. Never store plaintext passwords; `has_secure_password` handles hashing automatically.

**RSpec equivalent**:
```ruby
user = User.create(email: "admin@habitat.local", password: "secure123")
expect(user).to be_persisted
expect(user.password_digest).not_to eq "secure123"
expect(user.authenticate("secure123")).to eq user  # bcrypt verify
```

---

### Scenario 1.2: User requires unique email

```gherkin
Given a User exists with email "admin@habitat.local"
When another User is created with email "admin@habitat.local"
Then the second User is NOT saved
And the error message includes "email" and "taken" or "unique"
```

**Why this test?** Single-user system means only one email should exist. Validation prevents duplicates.

---

### Scenario 1.3: Login endpoint accepts valid credentials and returns JWT token

```gherkin
Given a User exists with email "admin@habitat.local" and password "secure123"
When POST /v1/login with email "admin@habitat.local" and password "secure123"
Then the response status is 200 OK
And the response body includes a "token" field
And the token is a valid JWT (three parts separated by dots)
And the JWT payload includes "user_id" and "exp" (expiry)
And the "exp" timestamp is approximately 1 day from now
```

**Why this test?** Login succeeds with correct credentials. Token format is JWT with 1-day expiry.

**RSpec equivalent**:
```ruby
post "/v1/login", params: { email: "admin@habitat.local", password: "secure123" }
expect(response).to have_http_status(200)
token = response.parsed_body["token"]
decoded = JWT.decode(token, Rails.application.secrets.jwt_secret)
expect(decoded[0]["user_id"]).to eq user.id
expect(decoded[0]["exp"]).to be_within(5).of(1.day.from_now.to_i)
```

---

### Scenario 1.4: Login endpoint rejects invalid email

```gherkin
Given a User exists with email "admin@habitat.local" and password "secure123"
When POST /v1/login with email "wrong@habitat.local" and password "secure123"
Then the response status is 401 Unauthorized
And the response body includes error message "Invalid email or password"
And NO token is returned
```

**Why this test?** Invalid email should not expose whether the email exists or not (security best practice: same error for both wrong email and wrong password).

---

### Scenario 1.5: Login endpoint rejects invalid password

```gherkin
Given a User exists with email "admin@habitat.local" and password "secure123"
When POST /v1/login with email "admin@habitat.local" and password "wrongpassword"
Then the response status is 401 Unauthorized
And the response body includes error message "Invalid email or password"
And NO token is returned
```

**Why this test?** Invalid password rejected. Same error message as wrong email (no information leakage).

---

## Capability 2: JWT Verification and Auth Middleware

Protected endpoints verify the JWT token and reject requests without auth (401).

### Scenario 2.1: Protected endpoints reject requests without Authorization header

```gherkin
Given a User exists and is logged in (token obtained)
When GET /v1/devices without Authorization header
Then the response status is 401 Unauthorized
And the response body includes error message about missing or invalid token
```

**Why this test?** Auth middleware blocks unauthenticated requests. All endpoints (even GETs) require auth.

**RSpec equivalent**:
```ruby
get "/v1/devices"  # No Authorization header
expect(response).to have_http_status(401)
```

---

### Scenario 2.2: Protected endpoints reject requests with invalid token

```gherkin
Given a User exists and is logged in
When GET /v1/devices with Authorization header "Bearer invalid_token_format"
Then the response status is 401 Unauthorized
And the response body includes error message about invalid token
```

**Why this test?** Malformed or tampered tokens are rejected.

---

### Scenario 2.3: Protected endpoints reject requests with expired token

```gherkin
Given a User exists
When a token is generated with expiry set to 1 second ago
And GET /v1/devices with Authorization header "Bearer <expired_token>"
Then the response status is 401 Unauthorized
And the response body includes error message about expired token
```

**Why this test?** Tokens expire after 1 day. Expired tokens (>1 day old) are rejected, forcing re-login.

---

### Scenario 2.4: Protected endpoints accept valid, non-expired token

```gherkin
Given a User exists with email "admin@habitat.local"
When POST /v1/login and receive a valid token
And GET /v1/devices with Authorization header "Bearer <token>"
Then the response status is 200 OK
And @current_user is set to the logged-in user
And the response includes device data
```

**Why this test?** Valid, non-expired tokens allow access.

---

## Capability 3: Device CRUD Endpoints (Versioned, Authenticated)

RESTful endpoints for creating, reading, updating, deleting devices. All require auth. Responses use ActiveModel serialization.

### Scenario 3.1: GET /v1/devices lists all devices (auth required, ActiveModel format)

```gherkin
Given a User is logged in (valid token)
And 2 devices exist: "Tapo Plug 1" and "Tapo Plug 2"
When GET /v1/devices with valid Authorization header
Then the response status is 200 OK
And the response body is a JSON object with key "devices" (plural)
And the array includes both devices
And each device has fields: id, name, type, brand, model, room, status, created_at, updated_at
And each device includes nested "device_attributes" array (even if empty)
```

**Why this test?** List endpoint returns all devices in ActiveModel format with nested attributes.

**ActiveModel Response Format**:
```json
{
  "devices": [
    {
      "id": 1,
      "name": "Tapo Plug 1",
      "type": "smart_plug",
      "brand": "TP-Link",
      "device_attributes": []
    }
  ]
}
```

---

### Scenario 3.2: POST /v1/devices creates a device (auth required, validation errors return 422)

```gherkin
Given a User is logged in
When POST /v1/devices with:
  | name       | "Living Room Plug" |
  | type       | "smart_plug"       |
  | brand      | "TP-Link"          |
  | model      | "Tapo P115"        |
  | room       | "Living Room"      |
And valid Authorization header
Then the response status is 201 Created
And the response body includes the created device with id
And the device is saved to the database
```

**Why this test?** Device creation requires auth. Successful creation returns 201.

---

### Scenario 3.3: POST /v1/devices with invalid data returns 422 validation errors

```gherkin
Given a User is logged in
When POST /v1/devices with:
  | name | (empty) |
  | type | (empty) |
And valid Authorization header
Then the response status is 422 Unprocessable Entity
And the response body is:
  {
    "errors": {
      "name": ["can't be blank"],
      "type": ["can't be blank"]
    }
  }
And NO device is saved
```

**Why this test?** Validation errors return 422 with Rails-default error format (errors: { field: ["message"] }).

---

### Scenario 3.4: GET /v1/devices/:id shows a device with nested device_attributes

```gherkin
Given a User is logged in
And a Device exists with 2 device_attributes (power_w: 12.5, voltage_v: 230)
When GET /v1/devices/:id with valid Authorization header
Then the response status is 200 OK
And the response body includes the device with all fields
And the "device_attributes" array includes both attributes:
  [
    { "id": 1, "key": "power_w", "value": "12.5", "created_at": "...", "updated_at": "..." },
    { "id": 2, "key": "voltage_v", "value": "230", "created_at": "...", "updated_at": "..." }
  ]
```

**Why this test?** Show endpoint returns device with nested attributes in ActiveModel format.

---

### Scenario 3.5: PATCH /v1/devices/:id updates a device

```gherkin
Given a User is logged in
And a Device exists with name "Old Name"
When PATCH /v1/devices/:id with:
  | name | "New Name" |
And valid Authorization header
Then the response status is 200 OK
And the device's name is updated to "New Name"
And the response body reflects the updated device
```

**Why this test?** Update endpoint requires auth, returns 200, persists changes.

---

### Scenario 3.6: DELETE /v1/devices/:id deletes a device and cascades to attributes

```gherkin
Given a User is logged in
And a Device exists with 2 device_attributes
When DELETE /v1/devices/:id with valid Authorization header
Then the response status is 204 No Content
And the Device is deleted from the database
And all 2 device_attributes are also deleted (cascade)
```

**Why this test?** Delete returns 204 (no content). Cascade delete prevents orphaned attributes.

---

### Scenario 3.7: GET /v1/devices/:id returns 404 if device doesn't exist

```gherkin
Given a User is logged in
When GET /v1/devices/999 (non-existent id) with valid Authorization header
Then the response status is 404 Not Found
```

**Why this test?** Non-existent resources return 404.

---

## Capability 4: DeviceAttribute Nested CRUD Endpoints

Versioned nested endpoints for managing attributes within a device. All require auth.

### Scenario 4.1: GET /v1/devices/:device_id/device_attributes lists attributes for a device

```gherkin
Given a User is logged in
And a Device exists with 3 device_attributes
When GET /v1/devices/:device_id/device_attributes with valid Authorization header
Then the response status is 200 OK
And the response body is { "device_attributes": [ ... ] } with 3 items
And each attribute has: id, key, value, created_at, updated_at
```

**Why this test?** Nested list endpoint returns attributes for a specific device.

---

### Scenario 4.2: POST /v1/devices/:device_id/device_attributes adds attribute to device

```gherkin
Given a User is logged in
And a Device exists with 0 attributes
When POST /v1/devices/:device_id/device_attributes with:
  | key   | "power_w" |
  | value | "12.5"    |
And valid Authorization header
Then the response status is 201 Created
And the attribute is added to the device
And the device now has 1 attribute
```

**Why this test?** Nested create requires device_id in URL, validates it belongs to that device.

---

### Scenario 4.3: POST /v1/devices/:device_id/device_attributes with missing key/value returns 422

```gherkin
Given a User is logged in
And a Device exists
When POST /v1/devices/:device_id/device_attributes with:
  | value | "12.5" |
  (key is missing)
And valid Authorization header
Then the response status is 422 Unprocessable Entity
And the response body is:
  {
    "errors": {
      "key": ["can't be blank"]
    }
  }
```

**Why this test?** Validation errors return 422 with standard Rails format.

---

### Scenario 4.4: POST /v1/devices/:device_id/device_attributes rejects duplicate key

```gherkin
Given a User is logged in
And a Device exists with 1 attribute (key: "power_w", value: "12.5")
When POST /v1/devices/:device_id/device_attributes with:
  | key   | "power_w" |
  | value | "13.0"    |
And valid Authorization header
Then the response status is 422 Unprocessable Entity
And the response body includes error:
  {
    "errors": {
      "key": ["must be unique per device"]
    }
  }
And the device still has only 1 attribute
```

**Why this test?** Key must be unique within a device. Duplicate key rejected with 422.

---

### Scenario 4.5: PATCH /v1/devices/:device_id/device_attributes/:id updates attribute

```gherkin
Given a User is logged in
And a Device exists with 1 attribute (key: "power_w", value: "12.5")
When PATCH /v1/devices/:device_id/device_attributes/1 with:
  | value | "15.0" |
And valid Authorization header
Then the response status is 200 OK
And the attribute's value is updated to "15.0"
And the key remains unchanged
```

**Why this test?** Update attribute value (key is immutable — enforce via spec/validation).

---

### Scenario 4.6: DELETE /v1/devices/:device_id/device_attributes/:id deletes attribute

```gherkin
Given a User is logged in
And a Device exists with 2 attributes
When DELETE /v1/devices/:device_id/device_attributes/1 with valid Authorization header
Then the response status is 204 No Content
And the attribute is deleted
And the device now has 1 attribute
```

**Why this test?** Delete returns 204. Attribute is removed without cascading device delete.

---

### Scenario 4.7: Nested endpoints verify device_id parameter

```gherkin
Given a User is logged in
And Device A exists with 0 attributes
And Device B exists with 0 attributes
When POST /v1/devices/A/device_attributes with data
And later GET /v1/devices/B/device_attributes
Then Device A has the new attribute
And Device B still has 0 attributes (attribute wasn't added to wrong device)
```

**Why this test?** Nested routing with device_id in URL prevents accidentally adding attributes to wrong device.

---

## Capability 5: Serialization Format (ActiveModel)

Consistent JSON structure across all endpoints using ActiveModel Serializer.

### Scenario 5.1: Device serialization includes all fields plus nested device_attributes

```gherkin
Given a Device with full data (name, type, brand, model, room, status, IP, MAC, etc.)
And the Device has 2 device_attributes
When serialized via ActiveModel
Then the JSON structure is:
  {
    "device": {
      "id": 1,
      "name": "Tapo Plug 1",
      "type": "smart_plug",
      "brand": "TP-Link",
      "model": "Tapo P115",
      "room": "Kitchen",
      "status": "online",
      "ip_address": "192.168.1.100",
      "mac_address": "AA:BB:CC:DD:EE:FF",
      "firmware_version": "1.2.4",
      "purchase_date": "2024-01-15",
      "notes": "Energy monitoring enabled",
      "created_at": "2026-08-03T22:30:00Z",
      "updated_at": "2026-08-03T22:30:00Z",
      "device_attributes": [
        { "id": 1, "key": "power_w", "value": "12.5", "created_at": "...", "updated_at": "..." }
      ]
    }
  }
```

**Why this test?** Validates serialization format matches ActiveModel expectation (not JSON:API, just plain nested JSON).

---

### Scenario 5.2: DeviceAttribute serialization includes key, value, timestamps

```gherkin
Given a DeviceAttribute with key "power_w" and value "12.5"
When serialized via ActiveModel
Then the JSON is:
  {
    "device_attribute": {
      "id": 1,
      "key": "power_w",
      "value": "12.5",
      "created_at": "2026-08-03T22:30:00Z",
      "updated_at": "2026-08-03T22:30:00Z"
    }
  }
```

**Why this test?** Validates minimal serialization for attributes (no need to include device_id since context is nested under device).

---

## Capability 6: Error Handling (Rails Default Format)

All endpoints follow consistent error response format.

### Scenario 6.1: Validation errors return 422 with errors object

```gherkin
Given any endpoint with invalid data
When request is sent
Then the response status is 422
And the response body is:
  {
    "errors": {
      "field_name": ["error message"]
    }
  }
```

**Why this test?** Rails-default format: `errors` key with field names as keys and array of messages.

---

### Scenario 6.2: Auth errors return 401 with error message

```gherkin
Given any request without valid token
When request is sent
Then the response status is 401
And the response body includes:
  {
    "errors": {
      "authentication": ["Invalid or expired token"]
    }
  }
```

**Why this test?** Auth failures return 401 with clear error message.

---

### Scenario 6.3: Not found errors return 404

```gherkin
Given a request for a non-existent resource (GET /v1/devices/999)
When request is sent with valid token
Then the response status is 404
```

**Why this test?** Missing resources return 404.

---

## Summary: Spec Scenarios

| Capability | Scenario Count | Coverage |
|------------|---|---|
| User & Login | 5 | User creation, uniqueness, login success/failure, credential validation |
| JWT Auth Middleware | 4 | Missing auth, invalid token, expired token, valid token acceptance |
| Device CRUD | 7 | List, create, create with errors, show, update, delete, 404 |
| DeviceAttribute Nested CRUD | 7 | List, create, create with errors, duplicate key rejection, update, delete, device_id verification |
| Serialization | 2 | Device with nested attributes, attribute solo format |
| Error Handling | 3 | Validation 422, auth 401, not found 404 |
| **Total** | **28 scenarios** | **Complete API coverage** |

---

## How These Specs Drive Implementation

Each scenario → one or more RSpec request specs (`spec/requests/v1/devices_spec.rb`, `spec/requests/v1/login_spec.rb`)

**RED phase**: All 28 scenarios FAIL (endpoints don't exist yet)

**GREEN phase**: Implement:
- User model with bcrypt
- Login endpoint (POST /v1/login)
- JWT verification concern (before_action)
- DeviceSerializer and DeviceAttributeSerializer
- Device controller with versioned routes (v1 namespace)
- DeviceAttribute controller with nested routes

**Expected**: All 28 tests pass after implementation

---

## Questions for Clarification Before Design Phase

1. **Should update (PATCH) on DeviceAttribute allow changing the key?**
   - Recommendation: No, key is immutable. Only value can change. This prevents confusion.
   - If yes, we need to enforce uniqueness on PATCH too.

2. **On DELETE /v1/devices, should we return the deleted device in response body or just 204 No Content?**
   - Recommendation: 204 No Content (no response body, just status). Simpler, follows REST convention.

3. **Should we add pagination to GET /v1/devices if there are many devices?**
   - Recommendation: Not in this cycle. Add in a future change if needed. Keep this change focused.

Confirm your preferences and we'll move to Design phase.
