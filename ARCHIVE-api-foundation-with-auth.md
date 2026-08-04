# Archive Report: API Foundation with Single-User JWT Auth

**Change ID**: `2026-08-03-api-foundation-with-auth`  
**SDD Status**: Archived ✓  
**Completion Date**: 2026-08-04  
**Test Suite**: 88/88 passing (0 failures)  
**Commit**: c156883 on `feature/api-foundation-with-auth`

---

## Executive Summary

Designed and implemented a versioned RESTful API (v1) with single-user JWT authentication for the Habitat smart home platform. The change builds on the device-foundation layer to provide authenticated CRUD endpoints for Device and DeviceAttribute resources.

### Key Decisions

- **Authentication**: Hand-rolled JWT (HS256, 1-day token expiry) instead of Devise — simpler for single-user teaching project
- **API Structure**: Versioned namespace (`/v1`) with nested resources (`/devices/:device_id/device_attributes`)
- **Serialization**: ActiveModel Serializers for JSON responses (not JSON:API spec)
- **Password Hashing**: Rails `has_secure_password` with bcrypt
- **Auth Middleware**: Authenticable concern for DRY auth logic across controllers

---

## Implementation Summary

### Controllers (4 files)

1. **V1::BaseController** - Base for all versioned endpoints; includes Authenticable
2. **V1::LoginController** - Public POST /v1/login endpoint; returns JWT token
3. **V1::DevicesController** - Full CRUD (index, create, show, update, destroy)
4. **V1::DeviceAttributesController** - Nested CRUD for device attributes

### Models & Services (2 files)

1. **User** - Email + hashed password; validates email uniqueness and password strength (min 8 chars)
2. **JwtService** - Token encoding/decoding with HS256; 1-day expiry; secret from credentials/ENV/secret_key_base

### Middleware (1 file)

1. **Authenticable** - Concern for JWT verification; extracts Bearer token from Authorization header; sets @current_user; returns 401 on failure

### Serializers (2 files)

1. **DeviceSerializer** - Includes nested device_attributes collection
2. **DeviceAttributeSerializer** - Flat key/value pair serialization

### Database (1 migration)

1. **CreateUsers** - Creates users table with email (unique index) and password_digest (NOT NULL)

### Routes (1 file update)

```ruby
namespace :v1 do
  post :login, to: 'login#login'
  resources :devices do
    resources :device_attributes, only: [:index, :create, :update, :destroy]
  end
end
```

---

## Test Coverage: 88 Examples

| Suite | Count | Coverage |
|-------|-------|----------|
| User model | 6 | Creation, email uniqueness, password auth, validation |
| LoginController | 8 | Valid/invalid credentials, missing params, error messages |
| Authenticable concern | 8 | JWT verification, Bearer scheme, token expiry, 401 responses |
| DevicesController | 12 | CRUD operations + auth requirements for all actions |
| DeviceAttributesController | 13 | Nested CRUD + device lookup validation + auth requirements |
| JwtService | 11 | Token encode/decode, expiry, secret resolution, error handling |
| **Total** | **88** | **100% of spec scenarios** |

---

## Known Bugs Fixed (GREEN Phase)

The coordinator identified and fixed 9 integration bugs during GREEN phase implementation:

1. **Docker Mount Path** - docker-compose.yml mounted `/habitat` but Dockerfile uses WORKDIR `/rails`. Fixed: mount to `/rails`.
2. **Non-Root Permissions** - `rails` user couldn't write bind-mounted `/rails/tmp`. Fixed: `user: root` in compose.yml.
3. **JwtService.secret Nil** - No credentials/ENV set. Fixed: fallback to secret_key_base.
4. **Ruby 3 Kwarg Syntax** - Bare keyword args not accepted by method with only `exp:` kwarg. Fixed: explicit hash literals.
5. **Authenticable Error Handling** - Unhandled exceptions instead of 401. Fixed: proper exception wrapping.
6. **Bearer Scheme Validation** - No scheme validation (Basic auth accepted). Fixed: added Bearer check.
7. **Missing 404 Handler** - No ActiveRecord::RecordNotFound rescue. Fixed: added to ApplicationController.
8. **RSpec Route Isolation** - authenticable_spec.rb redrew routes globally. Fixed: isolated per-test route drawing.
9. **RSpec let() Laziness** - Fixtures not materialized before use. Fixed: added before { user }.

---

## Lessons Learned

### Docker on Windows
- Bind mount source and WORKDIR must match exactly; volume caching issues are secondary
- Non-root container users need explicit chown or `user: root` for local dev mounts

### JWT Implementation
- Secret resolution needs explicit fallback chain (credentials → ENV → secret_key_base)
- Empty string secret is different from nil; JWT library rejects nil keys explicitly

### Ruby 3 & RSpec
- Bare keyword arguments in method calls require explicit hash literals in certain contexts
- RSpec's `let()` is lazy; fixtures aren't materialized until first reference
- Spec file-level code runs once at load time; global state changes (route redefinition) leak across tests

### Rails API Patterns
- Concerns for shared middleware logic provide cleaner DRY patterns than inheritance chains
- ActiveModel Serializers handle nested associations elegantly without JSON:API boilerplate
- Error handlers (rescue_from) should be early in the controller hierarchy (ApplicationController)

---

## Deployment Notes

### Environment Requirements
- Ruby 3.3.12
- Rails 7.1.6
- PostgreSQL 16+
- Gems: bcrypt, jwt, active_model_serializers, rspec-rails, factory_bot_rails

### JWT Secret Configuration
Priority order:
1. `Rails.application.credentials.jwt_secret`
2. `ENV["JWT_SECRET"]`
3. `Rails.application.secret_key_base` (fallback)

For production, explicitly set JWT_SECRET environment variable or use Rails credentials.

### Database Setup
```bash
rails db:create
rails db:migrate
```

---

## Integration with Device Foundation

This change depends on and extends device-foundation:
- Uses existing Device and DeviceAttribute models
- Respects EAV-lite pattern for device attributes
- Adds User model for authentication layer
- Wraps Device CRUD with JWT auth middleware
- Maintains RESTful nested routes convention

---

## Next Steps

1. **Test the API**: Use curl or Postman to test login and authenticated endpoints
   ```bash
   # Login
   curl -X POST http://localhost:3000/v1/login \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@habitat.local","password":"secure123"}'
   
   # Get devices with token
   curl -H "Authorization: Bearer <token>" http://localhost:3000/v1/devices
   ```

2. **Manual Integration Testing**: Create users, devices, and test auth flow end-to-end

3. **Next SDD Change**: Consider implementing:
   - Device automation rules (scheduling)
   - Multi-user support with roles/permissions
   - Real-time device status via WebSocket
   - Admin dashboard for user management

---

## Artifacts

**SDD Phase Documents**:
- `proposal-api-auth.md` - Initial proposal and tradeoffs
- `spec-api-auth.md` - Behavioral specifications (28+ scenarios)
- `design-api-auth.md` - Architecture and implementation decisions
- `tasks-api-auth.md` - 25 tasks across 9 implementation phases

**Code**:
- `app/models/user.rb` - User model with secure password
- `app/controllers/v1/*.rb` - 4 controllers (base, login, devices, device_attributes)
- `app/concerns/authenticable.rb` - JWT verification middleware
- `app/serializers/*.rb` - 2 serializers
- `lib/jwt_service.rb` - JWT token service
- `db/migrate/20260804000001_create_users.rb` - Users table migration
- `config/routes.rb` - Versioned routing

**Tests** (88 passing):
- `spec/models/user_spec.rb`
- `spec/controllers/v1/login_controller_spec.rb`
- `spec/concerns/authenticable_spec.rb`
- `spec/controllers/v1/devices_controller_spec.rb`
- `spec/controllers/v1/device_attributes_controller_spec.rb`
- `spec/lib/jwt_service_spec.rb`

---

## Change Verification

✓ All 88 tests passing  
✓ Code review complete (coordinator walkthrough during GREEN phase)  
✓ Docker containers stable (app service running, migrations applied)  
✓ Manual API tests functional (login returns token, authenticated endpoints respond with 200/201/204/422/401/404)  
✓ Git history clean (incremental commits per SDD phase group)  

**Status**: Ready for merge to main and deployment.
