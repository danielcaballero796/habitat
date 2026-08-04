# Proposal: API Foundation with Single-User JWT Auth

**Change ID**: `2026-08-03-api-foundation-with-auth`  
**Status**: Proposal  
**Created**: 2026-08-03

## Summary

Implement RESTful versioned API endpoints (`/v1/devices/*`) to expose the Device and DeviceAttribute models with ActiveModel serialization, Rails-default error handling, and hand-rolled single-user JWT authentication. This provides a secure, stateless API foundation for external clients (mobile app, dashboard, future external integrations) while keeping auth simple for a single-user home system.

## Why This Change?

**Problem**: The Device/DeviceAttribute models exist but are not accessible via HTTP. Building a mobile dashboard or external integrations requires API endpoints. Additionally, the user plans to potentially expose Habitat externally in the future, requiring authentication to prevent unauthorized device control.

**Solution**: Implement versioned REST endpoints with three orthogonal concerns:
1. **API Versioning** (`/v1/`) — enables future breaking changes without breaking existing clients
2. **Serialization** (ActiveModel Serializer) — clean JSON representation of Device/DeviceAttribute hierarchy
3. **Single-User JWT Auth** (hand-rolled) — lightweight, stateless authentication without Devise complexity

**Why hand-rolled JWT instead of Devise?**
- Devise is built for multi-user systems with email verification, password reset, role management
- Habitat is single-user with no email flows needed
- JWT is simpler: login once, get a token, include it in requests
- Hand-rolled allows full control and teaching value for understanding auth flows

**Why versioning despite being personal project?**
- User wants to keep the door open for external deployment later
- Versioning prevents API contract breakage: if future feature changes response format, v1 clients still work
- Best practice for any production API

## Scope

**In scope:**
- User model (email/username + password hash, single user)
- Login endpoint (`POST /v1/login`) — validates credentials, returns JWT token
- JWT verification (before_action concern on protected routes)
- Device endpoints (RESTful, nested, versioned):
  - `GET /v1/devices` — list all devices
  - `POST /v1/devices` — create device (requires auth)
  - `GET /v1/devices/:id` — show device with attributes
  - `PATCH /v1/devices/:id` — update device (requires auth)
  - `DELETE /v1/devices/:id` — delete device (requires auth)
- DeviceAttribute nested endpoints:
  - `GET /v1/devices/:device_id/device_attributes` — list attributes
  - `POST /v1/devices/:device_id/device_attributes` — add attribute (requires auth)
  - `PATCH /v1/devices/:device_id/device_attributes/:id` — update attribute (requires auth)
  - `DELETE /v1/devices/:device_id/device_attributes/:id` — delete attribute (requires auth)
- ActiveModel Serializer for Device and DeviceAttribute
- Rails-default error format: `{ errors: { field: ["message"] } }`
- JWT signing with secret key (stored in ENV or credentials)

**Out of scope:**
- Multi-user support, roles, permissions
- Refresh tokens or token expiration (stateless is fine for home API)
- Email verification or password reset flows
- OAuth2 or OIDC (overkill for single-user)
- Rate limiting (can add later if needed)
- CORS headers (can add when real external clients exist)

## Decisions & Rationale

### 1. API Versioning (`/v1/`)

**Decision**: Versioned routes starting with `/v1`

**Why**: If Habitat grows and response format changes (e.g., future feature adds new fields), v1 clients can still work. Unversioned APIs force all clients to upgrade simultaneously, which breaks the contract. For a personal project that might become external, versioning is low-cost insurance.

**Implementation**: Use Rails routing with `namespace :v1 { resources :devices ... }`

### 2. Serialization: ActiveModel Serializer

**Decision**: Use `active_model_serializers` gem, plain format (no JSON:API complexity)

**Example Response**:
```json
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

**Why**: ActiveModel Serializer is Rails-standard, minimal dependencies, easy to understand. JSON:API is over-engineered for this use case.

### 3. Error Format: Rails Default

**Decision**: Use Rails' default error format

**Example Error Response** (validation failed):
```json
{
  "errors": {
    "name": ["can't be blank"],
    "type": ["can't be blank"]
  }
}
```

**HTTP Status Codes**:
- 200 OK — successful GET
- 201 Created — successful POST (resource created)
- 204 No Content — successful DELETE
- 422 Unprocessable Entity — validation errors
- 401 Unauthorized — missing or invalid JWT token
- 500 Internal Server Error — server error

**Why**: Simple, matches Rails conventions, aligns with the simplicity of the serializer choice. No RFC 7807 boilerplate needed.

### 4. Authentication: Hand-Rolled Single-User JWT

**Decision**: Custom JWT auth implementation using `jwt` gem, no Devise

**Flow**:
1. User calls `POST /v1/login` with credentials (username/password or email/password)
2. Server validates against User table, returns signed JWT token:
   ```json
   {
     "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE2OTQwMDAwMDB9.signature"
   }
   ```
3. Client stores token, includes in subsequent requests: `Authorization: Bearer <token>`
4. Server verifies token via `before_action :verify_jwt` on protected routes
5. If token is invalid or expired, return 401 Unauthorized

**Why hand-rolled?**
- Devise is designed for multi-user, email verification, password reset — unnecessary complexity
- Hand-rolled JWT is ~50 lines of code: simple enough to understand and maintain
- Stateless: no session table needed, scales trivially

**Why not refresh tokens?**
- Single-user system, not prone to token theft
- Can add expiration (e.g., 7 days) and require re-login; that's fine for a home app

**User Model**:
```ruby
class User < ApplicationRecord
  has_secure_password  # bcrypt password hashing
  validates :email, uniqueness: true, presence: true
end
```

**Login Endpoint** (`POST /v1/login`):
```ruby
def login
  user = User.find_by(email: params[:email])
  if user&.authenticate(params[:password])
    token = JWT.encode({ user_id: user.id, exp: 7.days.from_now.to_i }, Rails.application.secrets.jwt_secret)
    render json: { token: token }
  else
    render json: { errors: { authentication: ["Invalid email or password"] } }, status: 401
  end
end
```

**JWT Verification Concern**:
```ruby
module Authenticable
  included do
    before_action :verify_jwt, except: [:login]
  end

  private

  def verify_jwt
    token = request.headers['Authorization']&.split(' ')&.last
    begin
      @current_user = User.find(JWT.decode(token, Rails.application.secrets.jwt_secret)[0]['user_id'])
    rescue JWT::DecodeError, JWT::ExpiredSignature
      render json: { errors: { authentication: ["Invalid or expired token"] } }, status: 401
    end
  end
end
```

### 5. Nested Resources: `/devices/:device_id/device_attributes`

**Decision**: RESTful nested routing

**Routes**:
```ruby
namespace :v1 do
  resources :devices do
    resources :device_attributes, only: [:index, :create, :update, :destroy]
  end
  post :login, on: :collection  # POST /v1/login
end
```

**Endpoints**:
- `GET /v1/devices` — all devices
- `POST /v1/devices` — create device
- `GET /v1/devices/:device_id` — show device
- `PATCH /v1/devices/:device_id` — update device
- `DELETE /v1/devices/:device_id` — delete device
- `GET /v1/devices/:device_id/device_attributes` — device's attributes
- `POST /v1/devices/:device_id/device_attributes` — add attribute to device
- `PATCH /v1/devices/:device_id/device_attributes/:id` — update attribute
- `DELETE /v1/devices/:device_id/device_attributes/:id` — delete attribute
- `POST /v1/login` — authenticate, get token

**Why nested?** Clear hierarchy, enforces device_id validation (can't add attribute to wrong device), REST-ful.

## Capabilities (for Spec phase)

1. **Authentication**
   - User can log in with email/password, receive JWT token
   - Invalid credentials return 401 Unauthorized
   - Token is required for protected endpoints

2. **Device CRUD**
   - List devices (GET, no auth required for read? or auth required for all? **decision needed**)
   - Create device (POST, requires auth)
   - Show device with attributes (GET)
   - Update device (PATCH, requires auth)
   - Delete device (DELETE, requires auth, cascade deletes attributes)

3. **DeviceAttribute CRUD (Nested)**
   - List attributes for device (GET)
   - Add attribute to device (POST, requires auth)
   - Update attribute (PATCH, requires auth)
   - Delete attribute (DELETE, requires auth)

4. **Serialization**
   - Device serialized with all fields + nested device_attributes
   - DeviceAttribute serialized with key, value, timestamps

5. **Error Handling**
   - Validation errors return 422 with error messages
   - Auth failures return 401
   - Not found returns 404

## Questions for You Before Spec Phase

**1. Should GET endpoints require auth?**
- **Option A**: Yes, require auth for all endpoints (reading devices is sensitive)
- **Option B**: No, reads don't require auth, only writes (POST/PATCH/DELETE) do

I'd recommend **Option A** (auth for all) since you might expose this externally and even reading device state could be sensitive.

**2. Should we add token expiration?**
- If yes, how long? (7 days? 30 days? This is a preference decision for your use case)
- This can also be added in a future change if you want to keep this cycle simple

I'd recommend **7 days** as a reasonable default.

Confirm these two questions and we'll move to Spec phase.

## Rollback Plan

If API breaks functionality:
1. All code is isolated in controllers + serializers, models are unchanged
2. Rollback: `git reset --hard HEAD~N` (where N is the number of commits)
3. No database migrations for auth users yet (single user can be hardcoded for now)

## Success Criteria

- [ ] User can log in with email/password, receive JWT token
- [ ] Protected endpoints reject requests without token (401)
- [ ] Protected endpoints reject requests with invalid token (401)
- [ ] Device endpoints support CRUD (create, read, update, delete)
- [ ] DeviceAttribute endpoints support CRUD with correct device_id nesting
- [ ] Serialization matches ActiveModel format (device + nested attributes)
- [ ] Error responses use Rails default format (errors: { field: ["message"] })
- [ ] All endpoints return correct HTTP status codes (200, 201, 204, 401, 404, 422)
- [ ] Spec scenarios for each endpoint all pass (RED → GREEN)

## Timeline

Single session, ~60–90 minutes:
- Proposal: 5 min (this document)
- Spec: 15 min (login + 8 endpoints = ~9 scenarios)
- Design: 5 min (Rails routing, serializers, auth concern)
- Tasks: 10 min (implementation steps)
- Apply: 40 min (controllers, serializers, migrations, tests)
- Verify: 5 min (test suite pass)
- Archive: 5 min (merge to baseline)

---

## Questions for Confirmation

Before moving to Spec phase, please confirm:

1. **GET endpoint auth**: All endpoints require auth (including reads), or auth only for POST/PATCH/DELETE?
2. **Token expiration**: 7 days, or different timeframe?
3. **Login endpoint**: Should we use email or username? (email is more secure, easier to remember than username)

Once you confirm, I'll write the Spec phase.
