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
