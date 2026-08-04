# Proposal: Device Dashboard with Rails Turbo/Hotwire

**Change ID**: `2026-08-04-device-dashboard`  
**Architecture Decision**: Option A — Rails + Turbo/Hotwire (same codebase, server-rendered ERB views)  
**Status**: PROPOSE phase  
**Scope**: Full CRUD dashboard — devices (list, create, view, update, delete) + nested device attributes (create, update, delete)

---

## Why Option A for Habitat

You chose **Rails + Turbo/Hotwire** because:

1. **Teaches the complete Rails stack**: You've learned models (Device), controllers (API logic), migrations, and testing. The dashboard adds views (ERB templates) and modern Rails interactivity (Turbo for form submissions without page reloads).

2. **Stays in the Ruby ecosystem**: No JavaScript framework to learn (yet). Stimulus.js is Rails' lightweight alternative to React/Vue — you write minimal JavaScript and let server-rendered HTML do the work.

3. **Fastest to shipping**: 3-5 days of development (not weeks). Turbo is built for server-rendered Rails apps and handles a lot of complexity for you.

4. **Real-world modern Rails**: Turbo is how real Rails shops (GitHub, Shopify, etc.) build modern web apps without leaving Ruby.

5. **Future flexibility**: If Habitat grows and you later want a separate mobile app or desktop client, the API stays untouched. The dashboard is purely UI-layer.

---

## Concrete Feature Set (Full CRUD Dashboard)

### What's IN Scope

**Dashboard Home**: Single entry point after login
```
/dashboard
  Shows: "Welcome, admin@habitat.local | Logout"
  Shows: List of all devices (summary view with action buttons)
  Shows: Button to "Add New Device"
```

**Feature 1: View Devices List**
```
GET /dashboard/devices (server-rendered ERB)

Displays:
  - Device name
  - Device type (smart_plug, led_controller, etc.)
  - Device status (online, offline, etc.)
  - Action links: View, Edit, Delete
  - "Add New Device" button at top
  
Example:
  [Living Room Plug]      [smart_plug] [online]    [View] [Edit] [Delete]
  [Bedroom Light]         [led_controller] [online] [View] [Edit] [Delete]
  [+ Add New Device]
```

**Feature 2: Create New Device (Turbo Form)**
```
GET /dashboard/devices/new (show form)
POST /dashboard/devices (create via Turbo)

Form fields:
  - Name (required)
  - Type (dropdown: smart_plug, led_controller, etc.)
  - Brand (optional)
  - Model (optional)
  - Room (optional)
  - Status (optional)
  - IP Address (optional)
  - MAC Address (optional)
  - Firmware Version (optional)
  - Purchase Date (optional)
  - Notes (optional)

Flow:
  1. User clicks "Add New Device"
  2. Turbo modal/drawer opens with form (no page reload)
  3. User fills form, submits
  4. Server creates device via existing POST /v1/devices endpoint
  5. Turbo adds new device to list (no refresh)
  6. Flash message "Device created successfully"
```

**Feature 3: View Device Details**
```
GET /dashboard/devices/:id (server-rendered ERB)

Displays:
  - Device name, type, brand, model, room, IP, MAC, firmware version, purchase date, notes
  - Edit/Delete buttons for device
  - All device attributes in a table:
    | Key        | Value  | Last Updated | Actions |
    | power_w    | 12.5   | 2026-08-04   | [Edit] [Delete] |
    | voltage_v  | 230    | 2026-08-04   | [Edit] [Delete] |
  - "Add New Attribute" button below table
```

**Feature 4: Edit Device (Turbo Action)**
```
GET /dashboard/devices/:id/edit (show edit form)
PATCH /dashboard/devices/:id (update via Turbo)

Flow:
  1. User clicks "Edit" on device card or detail page
  2. Turbo form appears (in-place or modal)
  3. User modifies fields, submits
  4. Server updates device via existing PATCH /v1/devices/:id
  5. Turbo replaces device data with updated values
  6. Flash message "Device updated"
```

**Feature 5: Delete Device (Turbo Action)**
```
DELETE /dashboard/devices/:id (Turbo confirmation)

Flow:
  1. User clicks "Delete" on device
  2. Turbo shows confirmation dialog
  3. On confirm, sends DELETE to /v1/devices/:id
  4. Turbo removes device from list (no reload)
  5. Flash message "Device deleted"
```

**Feature 6: Create Device Attribute (Turbo Form)**
```
GET /dashboard/devices/:id/attributes/new (show form)
POST /dashboard/devices/:id/attributes (create via Turbo)

Form fields:
  - Key (required, text: "power_w", "voltage_v", etc.)
  - Value (required, text: "12.5", "230", etc.)

Flow:
  1. User clicks "Add New Attribute" on device detail page
  2. Turbo form appears inline (in table or below)
  3. User enters key/value, submits
  4. Server creates attribute via existing POST /v1/devices/:device_id/device_attributes
  5. Turbo adds row to attributes table (no page reload)
  6. Flash message "Attribute added"
```

**Feature 7: Edit Device Attribute (Turbo Action)**
```
GET /dashboard/devices/:id/attributes/:attr_id/edit (show form)
PATCH /dashboard/devices/:id/attributes/:attr_id (update via Turbo)

Editable fields:
  - Value (key is immutable)

Flow:
  1. User clicks "Edit" on attribute row
  2. Turbo inline form appears (table cell becomes input)
  3. User updates value, submits
  4. Server updates via existing PATCH /v1/devices/:device_id/device_attributes/:id
  5. Turbo updates table row (no reload)
  6. Flash message "Attribute updated"
```

**Feature 8: Delete Device Attribute (Turbo Action)**
```
DELETE /dashboard/devices/:id/attributes/:attr_id (Turbo confirmation)

Flow:
  1. User clicks "Delete" on attribute row
  2. Turbo shows confirmation (optional, can be inline)
  3. On confirm, sends DELETE to /v1/devices/:device_id/device_attributes/:id
  4. Turbo removes row from attributes table (no reload)
  5. Flash message "Attribute deleted"
```

### What's OUT of Scope (For This Change)

❌ Automation rules or scheduling  
❌ Real-time status updates (would need WebSocket)  
❌ Search/filter devices  
❌ Pagination (assuming <50 devices)  
❌ Device history or logs  
❌ Mobile responsiveness (basic styling only)  
❌ Admin panel for multi-user (single user only, matching current auth)  
❌ Attribute duplicate-key validation from UI (API endpoint validates, UI shows error)

### Nice-to-Have (If Time)

- Basic Bootstrap or Tailwind styling for readable UI
- Flash messages ("Device renamed successfully!")
- Loading indicators on Turbo actions
- Empty state message ("No devices yet")
- Confirmation dialogs for all destructive actions

---

## Architecture Overview (Rails Monolith)

```
Current State (API-only):
  app/controllers/v1/devices_controller.rb       [JSON responses]
  app/models/device.rb
  config/routes.rb                               [/v1/devices]

After Proposal (Monolith with Views):
  app/controllers/v1/devices_controller.rb       [JSON responses — unchanged]
  app/controllers/dashboards_controller.rb       [NEW: server-rendered views]
  app/controllers/dashboard/devices_controller.rb [NEW: dashboard CRUD forms]
  app/models/device.rb                           [unchanged]
  app/views/dashboards/index.html.erb            [NEW: home page]
  app/views/dashboard/devices/index.html.erb     [NEW: device list]
  app/views/dashboard/devices/show.html.erb      [NEW: device detail]
  app/views/dashboard/devices/_form.html.erb     [NEW: shared form for rename]
  app/javascript/controllers/confirm.js          [NEW: Stimulus controller for delete confirmation]
  config/routes.rb                               [NEW: namespace :dashboard routes]
```

**Key Pattern**: 
- API endpoints stay at `/v1/*` (used by external clients, curl, future mobile apps)
- Dashboard endpoints at `/dashboard/*` (used by web UI only)
- Both share the same models and database

---

## The Real Design Question: Authentication Strategy

### The Problem

Your current app has **JWT authentication** (token-based, stateless):
```
Client login: POST /v1/login → returns JWT token
Client request: GET /v1/devices with "Authorization: Bearer <token>"
Token expires: After 24 hours, client must login again
```

JWT is perfect for APIs and mobile apps (no server sessions, scales across multiple servers). But for a **browser UI**, there's a classic problem:

**Where does the browser store the JWT?**
- Option 1: `localStorage` — convenient, but vulnerable to XSS attacks (JavaScript can steal it)
- Option 2: `httpOnly` cookie — secure, but requires CSRF protection
- Option 3: Session storage — new concept for you

### Option 1: Hybrid Approach (Recommended for This Project)

Use **two separate authentication systems** in the same app:

```
For API Clients (external, curl, mobile):
  POST /v1/login → Returns JWT token in response body
  Use JWT for all API calls

For Browser UI (dashboard):
  POST /login → Sets httpOnly session cookie
  Browser automatically sends cookie with each request
  Session expires when user closes browser OR after 30 days
```

**Why this works**:
- API clients (like Postman or mobile apps) never see or need the session cookie
- Browser UI uses familiar session-based auth (Rails standard)
- No JavaScript needs to handle token storage (session cookie is automatic)
- More secure (httpOnly prevents XSS theft)
- Simpler Turbo/Rails experience (you don't think about tokens in views)

**How it works in code**:
```ruby
# app/controllers/login_controller.rb (unchanged API endpoint)
module V1
  class LoginController < ApplicationController
    def login
      # ... JWT auth logic ...
      render json: { token: token }  # Returns token in JSON for API clients
    end
  end
end

# app/controllers/sessions_controller.rb (NEW: session-based for browser)
class SessionsController < ApplicationController
  skip_before_action :verify_jwt  # This endpoint has no JWT requirement

  def create
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id  # Rails session cookie (httpOnly)
      redirect_to dashboard_path, notice: "Logged in!"
    else
      redirect_to login_path, alert: "Invalid credentials"
    end
  end

  def destroy
    session.delete(:user_id)
    redirect_to login_path, notice: "Logged out"
  end
end

# app/controllers/dashboard_controller.rb (NEW: dashboard base)
class DashboardController < ApplicationController
  skip_before_action :verify_jwt  # Dashboard uses sessions, not JWT
  
  before_action :require_login  # Custom filter for session auth
  
  private
  
  def require_login
    redirect_to login_path unless current_user
  end
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
end
```

**Tradeoffs**:
- ✓ Simple, Rails-standard, secure
- ✓ No JWT/token logic in browser
- ✗ API clients (curl, mobile) still use JWT (two auth schemes)
- ✗ Session state lives on server (doesn't scale across multiple servers, but fine for hobby/learning)

### Option 2: Single JWT System (More Complex)

Use JWT for **both** API and browser UI:
```
Browser stores JWT in localStorage
JavaScript reads token from localStorage for each API request
```

**Tradeoffs**:
- ✓ Single auth system (consistent)
- ✓ Stateless (scalable)
- ✗ Requires JavaScript in every request (Turbo can handle this, but adds complexity)
- ✗ XSS risk (localStorage can be stolen by malicious scripts)
- ✗ No automatic token refresh (user gets 401 when token expires mid-session)

### Option 3: Separate Auth for UI Only (Over-Engineering)

Use sessions **only** for browser, keep JWT **only** for API, never mix:
```
Keep existing /v1/login (JWT) as-is
Add separate /login endpoint (sessions)
```

**Tradeoffs**:
- ✓ Cleanest separation of concerns
- ✓ Each subsystem uses its ideal auth scheme
- ✗ Two login endpoints, duplicate auth logic, confusing for users
- ✗ Most complex to maintain

---

## Recommendation: Hybrid Session + JWT Approach

**Use Option 1** (hybrid) because:

1. **Session-based auth is Rails standard** — you've been learning Rails conventions; sessions are "the Rails way"
2. **No JavaScript complexity** — Turbo works best with server-rendered sessions
3. **Security is better** — httpOnly cookies prevent XSS attacks
4. **API stays unchanged** — existing /v1/login endpoint stays JWT (good for external clients)
5. **Simple to teach** — you'll learn both session and JWT concepts without overcomplicating either

The browser dashboard uses sessions. The API endpoints still use JWT. They coexist in the same Rails app, serving different clients.

---

## Why Turbo Makes This Easy

Turbo (Rails' modern form submission library) pairs perfectly with server-rendered sessions:

```erb
<!-- app/views/dashboard/devices/_device_card.html.erb -->
<div id="device-<%= device.id %>">
  <h3><%= device.name %></h3>
  <p><%= device.type %></p>
  
  <!-- Turbo form: submits via AJAX, no page reload -->
  <%= form_with model: [:dashboard, device], local: true do |f| %>
    <%= f.text_field :name, placeholder: "New name" %>
    <%= f.submit "Rename" %>
  <% end %>
  
  <!-- Turbo delete: shows confirmation, then removes from page -->
  <%= link_to "Delete", [:dashboard, device], 
      method: :delete, 
      data: { turbo_confirm: "Are you sure?" } %>
</div>

<!-- After form submit, Turbo replaces this <div> with updated HTML from server -->
<!-- No JavaScript, no token management — just server-rendered HTML and Turbo's magic -->
```

Turbo handles:
- Form submission via AJAX
- Receiving HTML response from server
- Replacing the DOM element
- Showing confirmation dialogs
- Handling errors

All with zero custom JavaScript in this example.

---

## Concrete Feature Breakdown (For Next Phase)

Once you confirm this proposal, I'll break down into tasks:

**Phase 1: Authentication Layer**
- Add SessionsController (login/logout forms)
- Add session-based login view (ERB form)
- Add current_user helper for views
- Verify JWT API auth still works

**Phase 2: Dashboard Views**
- Create DashboardController
- Create device list view (index)
- Create device detail view (show)
- Add basic styling (Bootstrap CDN)

**Phase 3: Turbo Actions**
- Rename device (in-place Turbo form)
- Delete device (Turbo confirmation + removal)
- Flash messages on success/error

**Phase 4: Tests**
- Integration tests for dashboard CRUD
- Session auth tests (can user see devices if not logged in?)
- Turbo form submission tests

**Phase 5: Polish**
- Empty state messaging
- Loading indicators
- Error handling and user feedback

---

## Summary: What's Being Proposed

| Item | Details |
|------|---------|
| **Scope** | MVP dashboard: list devices, view details, rename (Turbo), delete (Turbo) |
| **Architecture** | Rails monolith: existing API endpoints + new dashboard views |
| **Auth** | Hybrid: sessions for browser UI (new), JWT for API (unchanged) |
| **Frontend Framework** | Turbo + Stimulus (minimal JavaScript, Rails-native) |
| **Time Estimate** | 3-5 days of development |
| **Learning Value** | Complete Rails stack: views, forms, Turbo interactivity, session auth |
| **Next Step** | You confirm scope → I move to SPEC phase with detailed scenarios |

---

## Key Design Question to Answer (Before SPEC Phase)

**Confirm or modify the authentication strategy**:

1. **Are you comfortable with hybrid auth** (sessions for browser UI, JWT stays for API)?
   - This is the recommended path
   
2. **Or do you prefer single JWT system** (browser stores JWT, manage via JavaScript)?
   - More complex, but "unified" auth
   
3. **Or pure sessions only** (replace JWT with sessions everywhere)?
   - Simplest learning curve, but breaks API clients (curl, future mobile)

Once you confirm auth strategy + feature scope, I'll write detailed specifications and move to SPEC phase.

---

## Questions to Confirm Before Proceeding

1. ✓ Feature scope (list, detail, rename, delete) — does this match your vision?
2. ❓ **Authentication strategy** — hybrid sessions (recommended) or alternative?
3. ✓ Styling expectation (basic Bootstrap OK for MVP)?
4. ✓ Out-of-scope confirmation (no add device form, no attribute management yet)?

Answer these and we're ready for SPEC phase.
