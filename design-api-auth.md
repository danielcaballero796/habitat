# Design: API Foundation with Single-User JWT Auth

**Change ID**: `2026-08-03-api-foundation-with-auth`  
**Status**: Design  
**Created**: 2026-08-03

---

## Overview

This design describes the Rails application structure, JWT authentication system, and versioned REST API for Device/DeviceAttribute management. We're building on top of the existing Device/DeviceAttribute models (already in the codebase) by adding:
1. User model for single-user authentication
2. JWT token generation and verification
3. Versioned API controllers with nested resources
4. ActiveModel Serializers for JSON responses
5. Auth middleware (before_action concern) on protected routes

---

## Architecture Decision: Hand-Rolled JWT vs. Devise vs. Devise-JWT

**The Problem:** Habitat needs authentication, but we want to avoid unnecessary complexity.

**Three Approaches Considered:**

| Approach | Complexity | Multi-user? | Email flows? | Best for |
|----------|-----------|---|---|---|
| **No Auth** | None | N/A | N/A | LAN-only, no external access |
| **Devise** | High | Yes | Yes (email verification, reset) | Enterprise SaaS, multi-user |
| **Devise-JWT** | Medium | Yes | Partially | Mobile apps with multi-user |
| **Hand-rolled JWT** (chosen) | Low | No | No | Single-user, personal projects, simple auth |

**Why Hand-Rolled JWT?**
- Habitat is single-user (you, the homeowner)
- No email verification, password reset, or role management needed
- Hand-rolled JWT is ~100 lines of Rails code: one concern (auth verification) + one service (JWT encoding/decoding)
- Teaching value: you understand exactly how auth works
- Future-proof: if requirements evolve, you can extend it without ripping out Devise

**Why not Devise?**
- Devise is built for multi-user systems with complex email flows
- Adds ~50 dependencies, migrations, models, controllers, mailers
- You'd use 5% of its features; 95% is overhead

**Verdict:** Hand-rolled JWT is the right call for your use case.

---

## File Structure

After this change, the project will have:

```
habitat/
├── app/
│   ├── models/
│   │   ├── device.rb (already exists)
│   │   ├── device_attribute.rb (already exists)
│   │   └── user.rb (NEW)
│   ├── controllers/
│   │   ├── application_controller.rb (update)
│   │   └── v1/
│   │       ├── base_controller.rb (NEW - inherits from ApplicationController)
│   │       ├── login_controller.rb (NEW - login endpoint, no auth required)
│   │       ├── devices_controller.rb (NEW - CRUD endpoints, auth required)
│   │       └── device_attributes_controller.rb (NEW - nested CRUD, auth required)
│   ├── serializers/
│   │   ├── device_serializer.rb (NEW - ActiveModel format)
│   │   └── device_attribute_serializer.rb (NEW - ActiveModel format)
│   └── concerns/
│       └── authenticable.rb (NEW - JWT verification logic)
├── config/
│   ├── routes.rb (update - add v1 namespace)
│   └── credentials.yml.enc (update - add jwt_secret key)
├── lib/
│   └── jwt_service.rb (NEW - JWT encode/decode helpers)
├── db/
│   ├── migrate/
│   │   └── [timestamp]_create_users.rb (NEW - User table)
│   └── schema.rb (auto-updated after migration)
└── spec/
    ├── models/
    │   └── user_spec.rb (NEW - User model tests)
    └── requests/
        ├── v1/
        │   ├── login_spec.rb (NEW - login endpoint tests)
        │   ├── devices_spec.rb (NEW - device CRUD tests)
        │   └── device_attributes_spec.rb (NEW - attribute CRUD tests)
        └── v1_auth_spec.rb (NEW - JWT verification tests)
```

**Why this structure?**
- `v1/` namespace isolates versioned routes from future v2/v3
- `Authenticable` concern keeps auth logic DRY (reusable on multiple controllers)
- `JwtService` centralizes token generation/verification (testable, reusable)
- `Serializers` separate JSON presentation from model logic (clean separation of concerns)
- Specs mirror the code structure (request specs test API behavior, model specs test User)

---

## Database Schema

### User Table Migration

```ruby
# db/migrate/[timestamp]_create_users.rb
class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false, unique: true
      t.string :password_digest, null: false
      t.timestamps
    end
    
    add_index :users, :email, unique: true
  end
end
```

**Schema Details:**
- `email`: String, NOT NULL, UNIQUE index — single user, unique email for login
- `password_digest`: String, NOT NULL — bcrypt hash (never store plaintext passwords)
- `created_at`, `updated_at`: Rails timestamps
- **Why NOT store password?** Passwords should never be stored. Rails' `has_secure_password` automatically hashes passwords with bcrypt. Only the hash is stored.

**Final Schema:**
```
users (table)
├── id: integer (primary key)
├── email: string (NOT NULL, UNIQUE)
├── password_digest: string (NOT NULL, bcrypt hash)
├── created_at: datetime (NOT NULL)
└── updated_at: datetime (NOT NULL)
```

---

## User Model

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_secure_password  # Adds password= and authenticate() methods via bcrypt

  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 8 }

  # Encrypt password automatically on save (bcrypt)
  # Provides authenticate(password) method for login validation
end
```

**Why `has_secure_password`?**
- Automatically hashes passwords with bcrypt before saving
- Provides `.authenticate(password)` method to verify login credentials
- Raises error if password is blank (built-in validation)

**Why email uniqueness?**
- Single-user system: only one User should exist
- Email is the login identifier (email + password)

---

## JWT Service (Token Generation & Verification)

```ruby
# lib/jwt_service.rb
class JwtService
  def self.encode(payload, exp: 1.day.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, secret, "HS256")
  end

  def self.decode(token)
    JWT.decode(token, secret, true, algorithm: "HS256").first
  rescue JWT::DecodeError, JWT::ExpiredSignature => e
    raise AuthenticationError, e.message
  end

  private

  def self.secret
    Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"]
  end
end

class AuthenticationError < StandardError; end
```

**Why centralize JWT logic?**
- DRY principle: encode/decode logic in one place
- Testable: can test token generation independently
- Reusable: any controller can call `JwtService.encode()` or `JwtService.decode()`
- Error handling: custom `AuthenticationError` for consistent error responses

**Why HS256 algorithm?**
- HS256 (HMAC SHA-256): simple, fast, symmetric (same secret for encode/decode)
- Good for single-server systems (Habitat)
- RS256 (RSA) is overkill for single-server; better for distributed systems

**Why 1-day expiry?**
- Short expiry = more secure (stolen token only valid for 1 day)
- User re-logs in after 1 day (acceptable friction for home app)
- No refresh tokens needed (stateless is simpler)

---

## Authentication Middleware (Concern)

```ruby
# app/concerns/authenticable.rb
module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :verify_jwt, except: [:login]
  end

  private

  def verify_jwt
    token = extract_token_from_header
    begin
      @current_user = User.find(JwtService.decode(token)["user_id"])
    rescue JwtService::AuthenticationError, ActiveRecord::RecordNotFound
      render json: { errors: { authentication: ["Invalid or expired token"] } }, status: :unauthorized
    end
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    header&.split(" ")&.last || raise(JwtService::AuthenticationError, "Missing token")
  end
end
```

**How it works:**
1. `before_action :verify_jwt` runs BEFORE every controller action (except `:login`)
2. Extracts token from `Authorization: Bearer <token>` header
3. Decodes token using `JwtService.decode()` — raises error if invalid/expired
4. Finds User by user_id in token payload
5. Sets `@current_user` for use in controller actions
6. If any step fails, return 401 Unauthorized with error message

**Why a concern (mixin)?**
- DRY: multiple controllers include this; auth logic isn't duplicated
- Clear intent: including controllers declare "I need auth"
- Testable: `Authenticable` can be tested independently

---

## Controllers

### V1 Base Controller (Shared by all versioned endpoints)

```ruby
# app/controllers/v1/base_controller.rb
module V1
  class BaseController < ApplicationController
    include Authenticable
    # All controllers that inherit from V1::BaseController get JWT verification
    # (except for routes that skip it, like :login)
  end
end
```

**Why?**
- Single place to include `Authenticable`
- Future v2 routes can inherit from `V2::BaseController` with different auth logic if needed

### Login Controller (No Auth Required)

```ruby
# app/controllers/v1/login_controller.rb
module V1
  class LoginController < ApplicationController
    skip_before_action :verify_jwt  # If defined in ApplicationController
    # OR inherit from ApplicationController directly (no auth)

    def login
      user = User.find_by(email: params[:email])
      
      if user&.authenticate(params[:password])
        token = JwtService.encode(user_id: user.id)
        render json: { token: token }, status: :ok
      else
        render json: { errors: { authentication: ["Invalid email or password"] } }, status: :unauthorized
      end
    end
  end
end
```

**Why separate from BaseController?**
- Login endpoint doesn't require auth (can't log in if you're already required to be logged in!)
- Explicitly shows "this endpoint is public"

### Devices Controller (Auth Required)

```ruby
# app/controllers/v1/devices_controller.rb
module V1
  class DevicesController < BaseController
    def index
      devices = Device.all
      render json: devices, each_serializer: DeviceSerializer
    end

    def create
      device = Device.new(device_params)
      if device.save
        render json: device, serializer: DeviceSerializer, status: :created
      else
        render json: { errors: device.errors }, status: :unprocessable_entity
      end
    end

    def show
      device = Device.find(params[:id])
      render json: device, serializer: DeviceSerializer
    end

    def update
      device = Device.find(params[:id])
      if device.update(device_params)
        render json: device, serializer: DeviceSerializer
      else
        render json: { errors: device.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      device = Device.find(params[:id])
      device.destroy
      head :no_content  # 204 with no response body
    end

    private

    def device_params
      params.require(:device).permit(:name, :type, :brand, :model, :room, :status, :ip_address, :mac_address, :firmware_version, :purchase_date, :notes)
    end
  end
end
```

**Why `head :no_content`?**
- HTTP 204 means "success, no content to return"
- Appropriate for DELETE endpoints (client knows what was deleted)

### DeviceAttribute Controller (Auth Required, Nested)

```ruby
# app/controllers/v1/device_attributes_controller.rb
module V1
  class DeviceAttributesController < BaseController
    before_action :set_device

    def index
      attributes = @device.device_attributes
      render json: attributes, each_serializer: DeviceAttributeSerializer
    end

    def create
      attribute = @device.device_attributes.new(attribute_params)
      if attribute.save
        render json: attribute, serializer: DeviceAttributeSerializer, status: :created
      else
        render json: { errors: attribute.errors }, status: :unprocessable_entity
      end
    end

    def update
      attribute = @device.device_attributes.find(params[:id])
      if attribute.update(attribute_params)
        render json: attribute, serializer: DeviceAttributeSerializer
      else
        render json: { errors: attribute.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      attribute = @device.device_attributes.find(params[:id])
      attribute.destroy
      head :no_content
    end

    private

    def set_device
      @device = Device.find(params[:device_id])
    end

    def attribute_params
      params.require(:device_attribute).permit(:key, :value)
    end
  end
end
```

**Why `set_device` before action?**
- Ensures device_id in URL is valid
- Prevents accidentally adding attributes to non-existent device
- Nested routing enforces hierarchy

---

## Serializers (ActiveModel)

```ruby
# app/serializers/device_serializer.rb
class DeviceSerializer < ActiveModel::Serializer
  attributes :id, :name, :type, :brand, :model, :room, :status, :ip_address, :mac_address, :firmware_version, :purchase_date, :notes, :created_at, :updated_at
  
  has_many :device_attributes, serializer: DeviceAttributeSerializer
end
```

```ruby
# app/serializers/device_attribute_serializer.rb
class DeviceAttributeSerializer < ActiveModel::Serializer
  attributes :id, :key, :value, :created_at, :updated_at
end
```

**Why ActiveModel Serializers?**
- Rails-standard way to format JSON responses
- Automatically includes all listed attributes
- `has_many :device_attributes` nests attributes in JSON
- No need for JSON:API complexity

**Output Example:**
```json
{
  "device": {
    "id": 1,
    "name": "Tapo Plug 1",
    "type": "smart_plug",
    "device_attributes": [
      { "id": 1, "key": "power_w", "value": "12.5", "created_at": "...", "updated_at": "..." }
    ]
  }
}
```

---

## Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :v1 do
    post :login, to: 'login#login'  # POST /v1/login (public, no auth)
    
    resources :devices do
      resources :device_attributes, only: [:index, :create, :update, :destroy]
    end
  end
end
```

**Routes Generated:**
```
POST   /v1/login                                    → v1/login#login
GET    /v1/devices                                 → v1/devices#index
POST   /v1/devices                                 → v1/devices#create
GET    /v1/devices/:id                             → v1/devices#show
PATCH  /v1/devices/:id                             → v1/devices#update
DELETE /v1/devices/:id                             → v1/devices#destroy
GET    /v1/devices/:device_id/device_attributes    → v1/device_attributes#index
POST   /v1/devices/:device_id/device_attributes    → v1/device_attributes#create
PATCH  /v1/devices/:device_id/device_attributes/:id → v1/device_attributes#update
DELETE /v1/devices/:device_id/device_attributes/:id → v1/device_attributes#destroy
```

**Why nested resources?**
- URL structure mirrors domain hierarchy (attributes belong to devices)
- Routing enforces device_id (can't access attributes without specifying device)

---

## JWT Secret Management

**Why not hardcode the secret?**
- Secrets should NEVER be in git
- If code is compromised, secret is compromised
- Different environments (dev, staging, production) need different secrets

**Rails Credentials Approach (Recommended):**

```bash
rails credentials:edit --environment development
```

Add to `config/credentials/development.yml.enc`:
```yaml
jwt_secret: your-secret-key-here-min-32-characters
```

Access in code:
```ruby
Rails.application.credentials.jwt_secret
```

**Environment Variable Fallback:**

If you prefer ENV vars (e.g., for Docker secrets):
```bash
export JWT_SECRET="your-secret-key-here"
```

Access in code (same as above):
```ruby
Rails.application.credentials.jwt_secret || ENV["JWT_SECRET"]
```

**Why Rails credentials?**
- Built-in to Rails 5.2+
- Encrypts secrets at rest (can commit `credentials.yml.enc` safely)
- Different secrets per environment
- Better than ENV vars for source-controlled secrets

---

## Gem Dependencies

Add to `Gemfile`:
```ruby
gem "jwt"  # JWT token generation and verification
gem "active_model_serializers"  # ActiveModel JSON serialization
gem "bcrypt"  # Password hashing (usually pre-installed)
```

Run:
```bash
bundle install
```

**Why these gems?**
- `jwt`: Simple, standard JWT library
- `active_model_serializers`: Rails convention for JSON responses
- `bcrypt`: Industry-standard password hashing (built into Rails)

---

## Test Strategy

**Model Tests** (`spec/models/user_spec.rb`):
- User creation with email/password
- Email uniqueness validation
- Password hashing (bcrypt)
- `authenticate()` method

**Request Tests** (`spec/requests/v1/login_spec.rb`):
- POST /v1/login with valid credentials → 200 + token
- POST /v1/login with invalid credentials → 401
- POST /v1/login with missing fields → 401

**Auth Middleware Tests** (`spec/requests/v1_auth_spec.rb`):
- GET /v1/devices without token → 401
- GET /v1/devices with invalid token → 401
- GET /v1/devices with expired token → 401
- GET /v1/devices with valid token → 200

**CRUD Tests** (`spec/requests/v1/devices_spec.rb`, `spec/requests/v1/device_attributes_spec.rb`):
- All 28 spec scenarios from the Spec phase

---

## Architecture Diagram

```
HTTP Request
    ↓
Router (config/routes.rb)
    ↓
Controller (V1::DevicesController)
    ├─ before_action :verify_jwt
    │   ├─ Extract token from Authorization header
    │   ├─ JwtService.decode(token) — verify signature & expiry
    │   └─ Load @current_user
    ├─ Action (index, create, show, update, destroy)
    │   ├─ Query Device model
    │   ├─ Return updated data
    │   └─ Render via Serializer
    ↓
Serializer (DeviceSerializer)
    ├─ Format Device as JSON
    ├─ Include nested device_attributes
    └─ Use DeviceAttributeSerializer for each attribute
    ↓
HTTP Response (JSON)
```

---

## Why This Design?

| Decision | Rationale |
|----------|-----------|
| **Hand-rolled JWT** | Single-user, no Devise complexity |
| **Versioned routes (/v1/)** | Future-proof API for external deployment |
| **Nested resources** | RESTful, enforces device_id validation |
| **Authenticable concern** | DRY auth logic, reusable across controllers |
| **JwtService** | Centralized token logic, testable, reusable |
| **ActiveModel Serializers** | Rails convention, clean separation of concerns |
| **Rails credentials** | Secrets encrypted at rest, environment-specific |
| **1-day token expiry** | Balance security (short expiry) with UX (re-login after 1 day is acceptable) |
| **ALL endpoints require auth** | Security from day one (prevents future mistakes if exposed externally) |
| **404 on not found** | Standard REST convention for missing resources |
| **422 on validation error** | Rails convention for unprocessable/invalid data |
| **204 on DELETE** | Standard REST convention, no response body needed |

---

## Verification Checklist

After Apply phase completes:

- [ ] User model validates presence and uniqueness of email
- [ ] User model hashes password with bcrypt (password_digest stored, not password)
- [ ] Login endpoint returns JWT token on valid credentials (200)
- [ ] Login endpoint returns 401 on invalid credentials
- [ ] JWT verification middleware blocks requests without auth
- [ ] JWT verification middleware blocks requests with invalid/expired tokens
- [ ] Device endpoints return 401 without valid token
- [ ] Device endpoints return correct HTTP status codes (200, 201, 204, 404, 422)
- [ ] Device responses use ActiveModel serialization format
- [ ] Nested device_attributes endpoints enforce device_id
- [ ] Error responses use Rails-default format: `{ errors: { field: ["message"] } }`
- [ ] All 28 spec scenarios pass

---

## Next Phase: Tasks

The Tasks phase will break this Design into concrete implementation steps, following the TDD RED → GREEN → REFACTOR cycle.

Expected tasks:
- User model + migration (3 tasks)
- JwtService + Authenticable concern (2 tasks)
- Controllers (3 tasks)
- Serializers (2 tasks)
- Routes (1 task)
- Tests — RED phase (2 tasks for 28 scenarios)
- Tests — GREEN phase (fix failures) (1 task)
- Verify all tests pass (1 task)

**Total**: ~15–20 tasks, ~120–180 minutes to complete.
