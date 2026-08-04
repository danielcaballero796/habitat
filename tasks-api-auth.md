# Tasks: API Foundation with Single-User JWT Auth

**Change ID**: `2026-08-03-api-foundation-with-auth`  
**Status**: Tasks  
**Created**: 2026-08-03

---

## Overview

28+ behavioral scenarios → 28+ RSpec request specs → Rails implementation that makes them all pass.

**Execution Strategy**: RED → GREEN → VERIFY
1. **RED**: Write all test cases first (they fail because code doesn't exist)
2. **GREEN**: Implement User model, JWT service, controllers, serializers (tests pass)
3. **VERIFY**: Run full suite, confirm all 28+ tests pass

---

## Phase 0: Setup

### Task 0.1: Verify git state on feature branch [1 min]

```bash
cd C:\Users\Daniel\Desktop\habitat
git status
# Expected: "On branch feature/device-foundation"
# No uncommitted changes (all device-foundation code committed)
```

**Why?** Ensures clean state before starting new API change. We're still on the feature branch; next change could be on a new branch or continue on this one.

---

## Phase 1: User Model & Migration

### Task 1.1: Generate User model [3 min]

```bash
docker compose run --rm app rails generate model User email:string password_digest:string
# Creates:
# - app/models/user.rb
# - db/migrate/[timestamp]_create_users.rb
```

Then manually edit the migration to add constraints:

```bash
# Edit db/migrate/[timestamp]_create_users.rb
```

**Why generate?** Rails generator creates the migration and model file with proper timestamps. We'll edit the migration by hand to add NOT NULL and UNIQUE constraints.

---

### Task 1.2: Configure User model with has_secure_password [3 min]

Edit `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  has_secure_password  # Adds password= and authenticate() via bcrypt

  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 8 }
end
```

**Why?**
- `has_secure_password`: automatic bcrypt hashing on save, `.authenticate(password)` for login validation
- Email uniqueness: single-user system, one email only
- Password validation: minimum 8 characters for security

---

## Phase 2: JWT Infrastructure

### Task 2.1: Create JwtService [5 min]

Create `lib/jwt_service.rb`:

```ruby
class JwtService
  class AuthenticationError < StandardError; end

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
```

**Why?**
- Centralized token logic (encode/decode in one place)
- HS256: symmetric algorithm, fast, sufficient for single-server
- 1-day expiry: balance of security (short) and UX (acceptable re-login)
- Custom error: consistent error handling across app

---

### Task 2.2: Create Authenticable concern [5 min]

Create `app/concerns/authenticable.rb`:

```ruby
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

**Why?**
- `before_action :verify_jwt`: runs on every request (except :login)
- Extracts "Bearer <token>" from Authorization header
- Decodes token, finds User, sets `@current_user`
- Returns 401 on invalid/expired token
- DRY: included in controllers, not duplicated

---

## Phase 3: Controllers

### Task 3.1: Create V1::BaseController [3 min]

Create `app/controllers/v1/base_controller.rb`:

```ruby
module V1
  class BaseController < ApplicationController
    include Authenticable
    # All V1 endpoints that inherit from BaseController require auth
  end
end
```

**Why?** Single place to include `Authenticable`. Future v2 could use different auth strategy.

---

### Task 3.2: Create V1::LoginController [5 min]

Create `app/controllers/v1/login_controller.rb`:

```ruby
module V1
  class LoginController < ApplicationController
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

**Why?**
- Inherits from ApplicationController, NOT BaseController (no auth required for login)
- Validates email/password via bcrypt `.authenticate()`
- Same error message for both wrong email and wrong password (no information leakage)
- Returns JWT token on success (200)

---

### Task 3.3: Create V1::DevicesController [8 min]

Create `app/controllers/v1/devices_controller.rb`:

```ruby
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
      head :no_content
    end

    private

    def device_params
      params.require(:device).permit(:name, :type, :brand, :model, :room, :status, :ip_address, :mac_address, :firmware_version, :purchase_date, :notes)
    end
  end
end
```

**Why?**
- Inherits from BaseController (auth required via `before_action :verify_jwt`)
- CRUD actions: index (GET all), create (POST), show (GET one), update (PATCH), destroy (DELETE)
- Uses DeviceSerializer for JSON responses
- Validation errors return 422 with error messages
- DELETE returns 204 No Content (head :no_content)

---

### Task 3.4: Create V1::DeviceAttributesController [8 min]

Create `app/controllers/v1/device_attributes_controller.rb`:

```ruby
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

**Why?**
- Nested under V1::BaseController (auth required)
- `set_device` before_action ensures device_id is valid (prevents adding attributes to non-existent device)
- Only permits `key` and `value` in update (key is immutable, enforced by strong params)
- Same error/status handling as DevicesController

---

## Phase 4: Serializers

### Task 4.1: Create DeviceSerializer [4 min]

Create `app/serializers/device_serializer.rb`:

```ruby
class DeviceSerializer < ActiveModel::Serializer
  attributes :id, :name, :type, :brand, :model, :room, :status, :ip_address, :mac_address, :firmware_version, :purchase_date, :notes, :created_at, :updated_at
  
  has_many :device_attributes, serializer: DeviceAttributeSerializer
end
```

**Why?**
- Lists all Device fields to include in JSON
- `has_many :device_attributes` nests attributes in response
- ActiveModel Serializers is Rails convention

---

### Task 4.2: Create DeviceAttributeSerializer [3 min]

Create `app/serializers/device_attribute_serializer.rb`:

```ruby
class DeviceAttributeSerializer < ActiveModel::Serializer
  attributes :id, :key, :value, :created_at, :updated_at
end
```

**Why?** Minimal serialization (no device_id since context is nested under device).

---

## Phase 5: Routes

### Task 5.1: Configure versioned nested routes [3 min]

Edit `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  namespace :v1 do
    post :login, to: 'login#login'  # POST /v1/login (public, no auth)
    
    resources :devices do
      resources :device_attributes, only: [:index, :create, :update, :destroy]
    end
  end
end
```

**Why?**
- `namespace :v1`: all routes under `/v1/` (versioned API)
- `post :login`: public endpoint for authentication
- `resources :devices`: standard CRUD (index, create, show, update, destroy)
- Nested `device_attributes`: only [:index, :create, :update, :destroy] (no show for single attribute)

**Routes generated:**
```
POST   /v1/login
GET    /v1/devices
POST   /v1/devices
GET    /v1/devices/:id
PATCH  /v1/devices/:id
DELETE /v1/devices/:id
GET    /v1/devices/:device_id/device_attributes
POST   /v1/devices/:device_id/device_attributes
PATCH  /v1/devices/:device_id/device_attributes/:id
DELETE /v1/devices/:device_id/device_attributes/:id
```

---

## Phase 6: Test Infrastructure

### Task 6.1: Add RSpec gems and configure [3 min]

Already done from device-foundation change. Verify gems are installed:

```bash
docker compose run --rm app bundle list | grep rspec
# Expected: rspec-rails and factory_bot_rails present
```

If not present, add to Gemfile and run `docker compose build app && docker compose run --rm app bundle install`.

**Why?** RSpec + FactoryBot are the testing foundation. Should already be there from Phase 3 of device-foundation.

---

## Phase 7: RED Phase (Write All Tests)

### Task 7.1: Write User model tests [5 min]

Create `spec/models/user_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  describe "creation" do
    it "creates a User with email and password" do
      user = User.create(email: "admin@habitat.local", password: "secure123")
      expect(user).to be_persisted
      expect(user.email).to eq "admin@habitat.local"
      expect(user.password_digest).not_to eq "secure123"  # bcrypt hash, not plaintext
    end
  end

  describe "email uniqueness" do
    it "requires unique email" do
      User.create(email: "admin@habitat.local", password: "secure123")
      user2 = User.new(email: "admin@habitat.local", password: "secure123")
      expect(user2.save).to be false
      expect(user2.errors[:email]).not_to be_empty
    end
  end

  describe "authentication" do
    it "authenticates with correct password" do
      user = User.create(email: "admin@habitat.local", password: "secure123")
      expect(user.authenticate("secure123")).to eq user
    end

    it "rejects incorrect password" do
      user = User.create(email: "admin@habitat.local", password: "secure123")
      expect(user.authenticate("wrongpassword")).to be false
    end
  end
end
```

**Why?** User model tests validate bcrypt hashing, uniqueness, and authentication method.

---

### Task 7.2: Write login endpoint tests [6 min]

Create `spec/requests/v1/login_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "V1::Login", type: :request do
  describe "POST /v1/login" do
    before do
      @user = User.create(email: "admin@habitat.local", password: "secure123")
    end

    it "returns JWT token on valid credentials" do
      post "/v1/login", params: { email: "admin@habitat.local", password: "secure123" }
      expect(response).to have_http_status(200)
      token = response.parsed_body["token"]
      expect(token).to be_present
      decoded = JWT.decode(token, Rails.application.secrets.jwt_secret)
      expect(decoded[0]["user_id"]).to eq @user.id
    end

    it "returns 401 on invalid email" do
      post "/v1/login", params: { email: "wrong@habitat.local", password: "secure123" }
      expect(response).to have_http_status(401)
      expect(response.parsed_body["errors"]).to be_present
    end

    it "returns 401 on invalid password" do
      post "/v1/login", params: { email: "admin@habitat.local", password: "wrongpassword" }
      expect(response).to have_http_status(401)
      expect(response.parsed_body["errors"]).to be_present
    end
  end
end
```

**Why?** Login endpoint tests verify token generation and credential validation.

---

### Task 7.3: Write JWT auth middleware tests [6 min]

Create `spec/requests/v1_auth_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe "JWT Auth Middleware", type: :request do
  describe "protected endpoints" do
    before do
      @user = User.create(email: "admin@habitat.local", password: "secure123")
      @token = JwtService.encode(user_id: @user.id)
    end

    it "rejects request without Authorization header" do
      get "/v1/devices"
      expect(response).to have_http_status(401)
    end

    it "rejects request with invalid token" do
      get "/v1/devices", headers: { "Authorization" => "Bearer invalid_token" }
      expect(response).to have_http_status(401)
    end

    it "rejects request with expired token" do
      expired_token = JwtService.encode(user_id: @user.id, exp: 1.second.ago)
      get "/v1/devices", headers: { "Authorization" => "Bearer #{expired_token}" }
      expect(response).to have_http_status(401)
    end

    it "accepts request with valid token" do
      get "/v1/devices", headers: { "Authorization" => "Bearer #{@token}" }
      expect(response).to have_http_status(200)
    end
  end
end
```

**Why?** Auth middleware tests verify JWT verification works (valid tokens accepted, invalid/expired rejected).

---

### Task 7.4: Write Device CRUD tests [8 min]

Create `spec/requests/v1/devices_spec.rb` with tests for:
- GET /v1/devices lists all devices (200)
- POST /v1/devices creates device (201)
- POST /v1/devices with invalid data returns 422 validation errors
- GET /v1/devices/:id shows device with nested attributes (200)
- PATCH /v1/devices/:id updates device (200)
- DELETE /v1/devices/:id deletes device (204)
- GET /v1/devices/:id returns 404 if not found

**Why?** Device CRUD tests verify all 7 endpoint scenarios from spec.

---

### Task 7.5: Write DeviceAttribute nested CRUD tests [8 min]

Create `spec/requests/v1/device_attributes_spec.rb` with tests for:
- GET /v1/devices/:device_id/device_attributes lists attributes (200)
- POST /v1/devices/:device_id/device_attributes creates attribute (201)
- POST with missing key/value returns 422
- POST with duplicate key returns 422
- PATCH /v1/devices/:device_id/device_attributes/:id updates value (200)
- DELETE /v1/devices/:device_id/device_attributes/:id deletes attribute (204)
- Nested endpoints verify device_id (prevent wrong device association)

**Why?** DeviceAttribute CRUD tests verify nested routing and uniqueness validation.

---

### Task 7.6: Verify tests fail (RED phase) [2 min]

```bash
docker compose run --rm app bundle exec rspec spec/models/user_spec.rb spec/requests/v1/
```

**Expected**: All tests FAIL (red). No controllers/models implemented yet.

**Why?** RED phase confirms tests are ready before we implement.

---

## Phase 8: GREEN Phase (Implement)

### Task 8.1: Run User migration [3 min]

```bash
docker compose run --rm app rails db:migrate
```

**Expected**: Migration runs, users table created.

**Why?** Database must be set up before User model can persist data.

---

### Task 8.2: Verify User model (already implemented) [1 min]

User model was already written in Task 1.2. Just verify:

```bash
docker compose run --rm app rails console
# In console:
User.create(email: "test@local", password: "secure123")
# Should succeed, password_digest should be bcrypt hash
```

---

### Task 8.3: Run tests, fix failures [8 min]

```bash
docker compose run --rm app bundle exec rspec spec/models/user_spec.rb
docker compose run --rm app bundle exec rspec spec/requests/v1/login_spec.rb
```

**Fix any failures**:
- User model validations
- Login endpoint logic

**Why?** Model-level tests are quick to fix. Fix errors before moving to integration tests.

---

### Task 8.4: Run CRUD endpoint tests, fix failures [10 min]

```bash
docker compose run --rm app bundle exec rspec spec/requests/v1/devices_spec.rb spec/requests/v1/device_attributes_spec.rb
```

**Fix any failures**:
- Controller actions (index, create, show, update, destroy)
- Serializer output format
- Error handling

**Why?** Integration tests catch routing, controller logic, and serialization issues.

---

### Task 8.5: Run auth middleware tests, fix failures [5 min]

```bash
docker compose run --rm app bundle exec rspec spec/requests/v1_auth_spec.rb
```

**Expected**: Tests pass if JwtService and Authenticable concern are correct.

**Why?** Auth middleware is critical; isolated tests help verify it works before relying on it.

---

## Phase 9: Verify

### Task 9.1: Run full test suite [2 min]

```bash
docker compose run --rm app bundle exec rspec spec/models/ spec/requests/
```

**Expected**: All 28+ tests PASS (green).

**Success criteria:**
- 28 examples, 0 failures
- All User, login, CRUD, auth, serialization scenarios pass
- No deprecation warnings (other than Rails 7.1 fixture_path)

**Why?** Final verification that all spec scenarios are implemented correctly.

---

## Task Summary

| Phase | Task | Duration | Key Objective |
|-------|------|----------|---------------|
| 0.1 | Verify git state | 1 min | Clean feature branch |
| 1.1 | Generate User model | 3 min | Model + migration skeleton |
| 1.2 | Configure User with has_secure_password | 3 min | Bcrypt hashing, email uniqueness validation |
| 2.1 | Create JwtService | 5 min | Token encode/decode (HS256, 1-day expiry) |
| 2.2 | Create Authenticable concern | 5 min | JWT verification via before_action |
| 3.1 | Create V1::BaseController | 3 min | Auth requirement for all v1 endpoints |
| 3.2 | Create V1::LoginController | 5 min | Public login endpoint (POST /v1/login) |
| 3.3 | Create V1::DevicesController | 8 min | Device CRUD endpoints (GET/POST/PATCH/DELETE) |
| 3.4 | Create V1::DeviceAttributesController | 8 min | Nested attribute CRUD (GET/POST/PATCH/DELETE) |
| 4.1 | Create DeviceSerializer | 4 min | Device JSON + nested attributes |
| 4.2 | Create DeviceAttributeSerializer | 3 min | Attribute JSON format |
| 5.1 | Configure versioned nested routes | 3 min | /v1/ namespace, nested resources |
| 6.1 | Verify RSpec gems | 3 min | RSpec + FactoryBot installed |
| 7.1 | Write User model tests | 5 min | User creation, email uniqueness, authentication |
| 7.2 | Write login endpoint tests | 6 min | Login success/failure, token generation |
| 7.3 | Write JWT auth middleware tests | 6 min | Token validation, expiry, 401 errors |
| 7.4 | Write Device CRUD tests | 8 min | All 7 Device endpoint scenarios |
| 7.5 | Write DeviceAttribute nested CRUD tests | 8 min | All 7 DeviceAttribute endpoint scenarios |
| 7.6 | Verify tests fail (RED phase) | 2 min | Confirm tests are ready before implementation |
| 8.1 | Run User migration | 3 min | Create users table |
| 8.2 | Verify User model | 1 min | User creation and bcrypt work |
| 8.3 | Run tests, fix failures (model/login) | 8 min | User and login tests pass |
| 8.4 | Run tests, fix failures (CRUD) | 10 min | Device/attribute endpoint tests pass |
| 8.5 | Run tests, fix failures (auth) | 5 min | Auth middleware tests pass |
| 9.1 | Run full test suite | 2 min | All 28+ tests pass (GREEN phase complete) |
| **TOTAL** | | **~130 minutes** | API foundation with auth complete |

---

## Why This Task Breakdown?

**Model-first approach**: User model + migration come first (foundation)  
**Auth infrastructure before controllers**: JwtService and Authenticable must exist before controllers can use them  
**Controllers build on auth**: Each controller inherits from BaseController which includes Authenticable  
**Serializers last**: Controllers need to know serializers exist, so write serializers before running tests  
**Routes tie it together**: Routes are the final wiring  
**RED before GREEN**: Write all 28+ tests first, then implement. Tests drive development, not vice versa  
**Isolated test runs**: Model tests pass before controller tests to isolate failures  

---

## Next Phase: Apply

The **Apply phase** will execute these 25 tasks in order, running commands and writing code.

Expected time: ~2–2.5 hours (all 28+ spec scenarios passing)

Estimated flow:
- Phase 0: 1 min
- Phase 1: 6 min
- Phase 2: 10 min
- Phase 3: 24 min
- Phase 4: 7 min
- Phase 5: 3 min
- Phase 6: 3 min
- Phase 7 (RED): 35 min
- Phase 8 (GREEN): 27 min
- Phase 9 (VERIFY): 2 min
- **Total: ~118 minutes**

Then: Verify (confirm all tests pass) → Archive (commit + merge to baseline) → Next change ready
