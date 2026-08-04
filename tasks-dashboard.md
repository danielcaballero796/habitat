# Tasks: Device Dashboard Implementation

**Change ID**: `2026-08-04-device-dashboard`  
**Status**: TASKS phase  
**Created**: 2026-08-04  
**Total Tasks**: ~34 concrete, atomic tasks

This document breaks the dashboard design into testable, 5-10 minute implementation units organized by feature area and phase.

---

## Phase 1: Session Authentication & Login (5 tasks) — [x] COMPLETE

**Why this phase first**: Login is the gate to everything. Get session auth working before building dashboard views.

### Task 1.1: Create SessionsController — [x] DONE

```ruby
# app/controllers/sessions_controller.rb
# - Subclass ApplicationController
# - skip_before_action :verify_jwt
# - Actions: new (GET /login), create (POST /login), destroy (DELETE /logout)
# - Password verification: User.find_by(email:)&.authenticate(password)
# - On success: session[:user_id] = user.id, redirect to /dashboard
# - On failure: flash.now[:alert], re-render :new
```

**Testable**: Can POST /login with valid/invalid credentials, check session cookie set/cleared.

---

### Task 1.2: Create app/helpers/sessions_helper.rb — [x] DONE

```ruby
# - current_user helper method (User.find_by(id: session[:user_id]))
# - logged_in? helper (!!current_user)
# - require_login filter (redirect to /login if not logged in)
```

**Testable**: current_user returns correct User, logged_in? returns true/false.

---

### Task 1.3: Add ApplicationController changes for session auth — [x] DONE

```ruby
# app/controllers/application_controller.rb
# - Add helper_method :current_user (expose to views)
# - Add before_action that checks JWT for /v1/* routes only
#   (skip JWT for /login, /dashboard routes)
# - Ensure no conflict between JWT and session auth
```

**Testable**: API routes still require JWT, dashboard routes don't.

---

### Task 1.4: Create login view (sessions/new.html.erb) — [x] DONE

```erb
<!-- app/views/sessions/new.html.erb -->
<!-- - Form: email, password inputs -->
<!-- - Action: POST /login -->
<!-- - Styling: Bootstrap card, center aligned -->
<!-- - Link to homepage (if login fails) -->
```

**Testable**: Page loads at GET /login, form submits to POST /login.

---

### Task 1.5: Add routes for session auth — [x] DONE

```ruby
# config/routes.rb
# get '/login', to: 'sessions#new'
# post '/login', to: 'sessions#create'
# delete '/logout', to: 'sessions#destroy'
```

**Testable**: All three routes exist and route correctly.

---

## Phase 2: Dashboard Home Page (3 tasks) — [x] COMPLETE

**Why**: Landing page after login; lists all devices.

### Task 2.1: Create DashboardController — [x] DONE

```ruby
# app/controllers/dashboard_controller.rb
# - Subclass ApplicationController
# - skip_before_action :verify_jwt
# - before_action :require_login (from SessionsHelper)
# - Action: index (GET /dashboard)
#   - @devices = Device.all
#   - render :index
```

**Testable**: GET /dashboard requires login, returns list of devices.

---

### Task 2.2: Create dashboard home view (dashboard/index.html.erb) — [x] DONE

```erb
<!-- app/views/dashboard/index.html.erb -->
<!-- - Header: "Your Devices" + "Welcome, <%= current_user.email %>" -->
<!-- - Button: "+ Add New Device" (opens modal) -->
<!-- - Include devices list partial -->
<!-- - Include device modal partial (empty for now) -->
```

**Testable**: Page loads, shows heading + button, list renders.

---

### Task 2.3: Add dashboard route — [x] DONE

```ruby
# config/routes.rb
# get '/dashboard', to: 'dashboard#index'
```

**Testable**: GET /dashboard route exists, requires login.

---

## Phase 3: Stimulus Modal Controller & Integration (3 tasks) — [x] COMPLETE

**Why**: Modal interactivity foundation for all CRUD. Build reusable component first.

### Task 3.1: Create Stimulus modal controller (app/javascript/controllers/modal_controller.js) — [x] DONE

```javascript
// import { Controller } from "@hotwired/stimulus"
//
// open(event) {
//   event?.preventDefault()
//   this.element.classList.add("open")
//   this.element.querySelector("input:first-of-type")?.focus()
// }
//
// close(event) {
//   event?.preventDefault()
//   this.element.classList.remove("open")
//   this.resetForm()
// }
//
// closeOnBackdrop(event) {
//   if (event.target.classList.contains("modal-backdrop")) {
//     this.close()
//   }
// }
//
// closeViaStream() {
//   this.element.classList.remove("open")
//   this.resetForm()
// }
//
// resetForm() {
//   const form = this.element.querySelector("form")
//   if (form) {
//     form.reset()
//     form.querySelectorAll(".field_with_errors").forEach(...)
//   }
// }
```

**Testable**: Click open button → modal gets "open" class. Click backdrop → modal closes. Form resets after close.

---

### Task 3.2: Create shared modal component (_modal.html.erb) — [x] DONE

```erb
<!-- app/views/shared/_modal.html.erb -->
<!-- Parameters: id, title, content -->
<!-- - Div: .modal-overlay (display: none by default) -->
<!-- - Inner div: .modal-backdrop (click to close) -->
<!-- - Inner div: .modal-content -->
<!--   - Header with title + close button -->
<!--   - Body: <%= content %> (yielded) -->
<!-- - CSS: display:none, display:flex when .open class added -->
```

**Testable**: Modal renders with id, displays when .open class added, closes when .modal-close clicked.

---

### Task 3.3: Create custom Turbo Stream action for closing modals — [x] DONE

```javascript
// app/javascript/controllers/turbo_stream_actions.js
// Turbo.StreamActions.close_modal = function() {
//   const modalId = this.getAttribute("targets")  // or use dataset
//   const modal = document.querySelector(modalId)
//   if (modal) {
//     const controller = Stimulus.application.getControllerForElementAndIdentifier(modal, "modal")
//     controller?.closeViaStream()
//   }
// }
//
// Usage in controller: turbo_stream.action(:close_modal, "#device-modal")
```

**Testable**: Server sends `<turbo-stream action="close_modal" targets="#device-modal">`, modal closes.

---

## Phase 4: Devices List & CRUD Views (9 tasks) — [x] COMPLETE

**Why**: Core dashboard feature. Build list view first, then forms.

**Implementation note (/dashboard vs /dashboard/devices)**: `/dashboard`
(Phase 2, unchanged) stays a lightweight, read-only landing page — it still
passes its original Phase 2 request specs verbatim. `/dashboard/devices`
(this phase) is the fully functional CRUD surface with working
create/show/edit/update/destroy actions and Turbo Stream responses. They are
intentionally not merged, to avoid touching/breaking the already-tested
Phase 2 view. A "+ Add New Device" link on `/dashboard/devices` is the entry
point into the CRUD flow; wiring a nav link from `/dashboard` itself is left
to Phase 6 (Modal Integration & Forms) which ties the pages together.

**Deviation from design doc**: `config.api_only = true` (see
`config/application.rb`) makes Rails' `resources` macro exclude `:new` and
`:edit` routes by default (API-only apps don't render HTML forms). Fixed by
declaring `resources :devices, only: [:index, :show, :new, :create, :edit, :update, :destroy]`
explicitly in `config/routes.rb`. Also, `turbo_stream.action(:close_modal, "#device-modal")`
as written in the design doc produces `target="#device-modal"`, which Turbo
resolves client-side via `document.getElementById(this.target)` — the literal
`#` would never match a real element id. Implemented as
`turbo_stream.action(:close_modal, "device-modal")` (no `#`) instead, matching
how the `close_modal` custom Turbo Stream action (Phase 3) actually resolves
`targetElements`.

### Task 4.1: Create Dashboard::DevicesController — [x] DONE

```ruby
# app/controllers/dashboard/devices_controller.rb
# - Namespace: Dashboard
# - Subclass DashboardController (inherits require_login)
# - Actions: index, new, create, show, edit, update, destroy
# - Strong params: permit all device fields
# - Turbo responses in create/update/destroy (see tasks 4.6, 4.8, 4.9)
```

**Testable**: All CRUD actions exist, route to correct views.

---

### Task 4.2: Create devices list view (dashboard/devices/index.html.erb) — [x] DONE

```erb
<!-- Simplified version (full view in task 4.3) -->
<!-- - Header: "Your Devices" + "+ Add New Device" button -->
<!-- - Table: name, type, status, actions columns -->
<!-- - Each row: render 'device' partial -->
<!-- - Empty state: "You have no devices yet" with link to add -->
```

**Testable**: Page renders list of devices, empty state shows when no devices.

---

### Task 4.3: Create device card partial (dashboard/devices/_device.html.erb) — [x] DONE

```erb
<!-- app/views/dashboard/devices/_device.html.erb -->
<!-- - Table row (id="device-<%= device.id %>") -->
<!-- - Name, type, status columns -->
<!-- - Action buttons: [View] [Edit] [Delete] -->
<!-- - Edit & Delete buttons use data-turbo-method, data-action -->
```

**Testable**: Each device renders as table row with action buttons.

---

### Task 4.4: Create device new form modal (dashboard/devices/new.html.erb) — [x] DONE

```erb
<!-- app/views/dashboard/devices/new.html.erb -->
<!-- render 'shared/modal', id: 'device-modal', title: 'Add Device' do -->
<!--   render 'form', device: @device (or Device.new) -->
<!-- end -->
```

**Testable**: GET /dashboard/devices/new renders modal with form.

---

### Task 4.5: Create device form partial (dashboard/devices/_form.html.erb) — [x] DONE

```erb
<!-- app/views/dashboard/devices/_form.html.erb -->
<!-- form_with model: [:dashboard, device], local: true do -->
<!--   fields for: name, type (select), brand, model, room, status (select), -->
<!--   ip_address, mac_address, firmware_version, purchase_date, notes -->
<!--   button: "Create" or "Update" + "Guardando..." during submit -->
<!-- end -->
```

**Testable**: Form renders all fields, button changes text during submit.

---

### Task 4.6: Implement create action (POST /dashboard/devices) — [x] DONE

```ruby
# In Dashboard::DevicesController#create
# - @device = Device.new(device_params)
# - if @device.save:
#     render turbo_stream: [
#       turbo_stream.action(:close_modal, "#device-modal"),
#       turbo_stream.prepend('devices-list', partial: 'device', locals: {...}),
#       turbo_stream.update('flash', partial: 'shared/flash', ...)
#     ]
# - else:
#     render :new, status: 422, layout: false
```

**Testable**: Submit form → device created → modal closes → device appears in list → flash message shows.

---

### Task 4.7: Create device show view (dashboard/devices/show.html.erb) — [x] DONE

```erb
<!-- app/views/dashboard/devices/show.html.erb -->
<!-- Header with device name -->
<!-- Device details: type, brand, model, room, status, IP, MAC, etc. -->
<!-- Action buttons: [Back] [Edit] [Delete] -->
<!-- Nested section: Device Attributes table -->
<!-- Modals for edit & delete confirmation -->
```

**Testable**: GET /dashboard/devices/:id renders device details + nested attributes.

---

### Task 4.8: Implement update action (PATCH /dashboard/devices/:id) — [x] DONE

```ruby
# In Dashboard::DevicesController#update
# - @device.update(device_params)
# - if valid:
#     render turbo_stream: [
#       turbo_stream.action(:close_modal, "#device-modal"),
#       turbo_stream.replace("device-#{@device.id}", partial: 'device', ...),
#       turbo_stream.update('flash', ...)
#     ]
# - else:
#     render :edit, status: 422, layout: false
```

**Testable**: Submit edit form → device updates → modal closes → device row updates.

---

### Task 4.9: Implement delete action (DELETE /dashboard/devices/:id) — [x] DONE

```ruby
# In Dashboard::DevicesController#destroy
# - @device.destroy
# - render turbo_stream: [
#     turbo_stream.action(:close_modal, "#confirm-delete-modal"),
#     turbo_stream.remove("device-#{@device.id}"),
#     turbo_stream.update('flash', ...)
#   ]
```

**Testable**: Confirm delete → device removed from list → flash shows "Device deleted".

---

## Phase 5: Device Attributes Nested CRUD (6 tasks)

**Why**: Nested resource CRUD; reuses modal pattern from devices.

### Task 5.1: Create Dashboard::DeviceAttributesController — [x] DONE

```ruby
# app/controllers/dashboard/device_attributes_controller.rb
# - Namespace: Dashboard
# - Subclass DashboardController
# - before_action :set_device (find Device by device_id)
# - Actions: new, create, edit, update, destroy
# - Strong params: permit :key, :value
```

**Testable**: All nested CRUD actions exist.

---

### Task 5.2: Create attributes list row partial (dashboard/device_attributes/_attribute.html.erb) — [x] DONE

```erb
<!-- app/views/dashboard/device_attributes/_attribute.html.erb -->
<!-- Table row (id="attribute-<%= attribute.id %>") -->
<!-- Columns: key, value, updated_at, actions -->
<!-- Action buttons: [Edit] [Delete] -->
```

**Testable**: Attribute renders as table row.

---

### Task 5.3: Create attribute form partial (dashboard/device_attributes/_form.html.erb) — [x] DONE

```erb
<!-- app/views/dashboard/device_attributes/_form.html.erb -->
<!-- form_with model: [:dashboard, device, attribute], local: true do -->
<!--   field :key (disabled if editing) -->
<!--   field :value -->
<!--   button: "Create"/"Update" + "Guardando..." -->
<!-- end -->
```

**Testable**: Form renders key (editable on create, read-only on update) + value.

---

### Task 5.4: Implement attribute create action (POST /dashboard/devices/:device_id/device_attributes) — [x] DONE

```ruby
# In Dashboard::DeviceAttributesController#create
# - @attribute = @device.device_attributes.new(attribute_params)
# - if @attribute.save:
#     render turbo_stream: [
#       turbo_stream.action(:close_modal, "#attribute-modal"),
#       turbo_stream.append('attributes-list', partial: 'attribute', ...),
#       turbo_stream.update('flash', ...)
#     ]
# - else:
#     render :new, status: 422, layout: false
```

**Testable**: Submit attribute form → row added to table → modal closes.

---

### Task 5.5: Implement attribute update action (PATCH) — [x] DONE

```ruby
# In Dashboard::DeviceAttributesController#update
# - @attribute.update(attribute_params)
# - if valid:
#     render turbo_stream: [
#       turbo_stream.action(:close_modal, "#attribute-modal"),
#       turbo_stream.replace("attribute-#{@attribute.id}", ...),
#       turbo_stream.update('flash', ...)
#     ]
# - else:
#     render :edit, status: 422, layout: false
```

**Testable**: Edit attribute → row updates in table.

---

### Task 5.6: Implement attribute delete action (DELETE) — [x] DONE

```ruby
# In Dashboard::DeviceAttributesController#destroy
# - @attribute.destroy
# - render turbo_stream: [
#     turbo_stream.action(:close_modal, "#confirm-delete-modal"),
#     turbo_stream.remove("attribute-#{@attribute.id}"),
#     turbo_stream.update('flash', ...)
#   ]
```

**Testable**: Delete attribute → row removed from table.

---

## Phase 6: Modal Integration & Forms (4 tasks)

**Why**: Tie together modals, forms, Turbo responses.

### Task 6.1: Create delete confirmation modals for devices & attributes — [x] DONE

```erb
<!-- app/views/dashboard/devices/_delete_confirmation.html.erb -->
<!-- Prompt: "Are you sure?" + device name -->
<!-- Two buttons: [Confirm Delete] [Cancel] -->
<!-- Confirm button: form POST with method: delete -->
<!-- Cancel button: data-action="click->modal#close" -->
```

**Testable**: Click delete → modal shows → confirm/cancel buttons work.

**Implementation note**: Replaced `data-turbo-confirm` on devices index/show and
attribute rows with real modal-based confirmations (`#confirm-delete-modal` on
devices index/show, `#confirm-delete-attribute-modal` on the show page's
attributes section — two distinct ids since a device show page contains both a
device-delete and multiple attribute-delete contexts on the same DOM). Added a
new `app/javascript/controllers/confirm_delete_controller.js` (`data-controller="confirm-delete"`,
scoped on an ancestor wrapping both the trigger links and their modal) that
copies `data-delete-url`/`data-delete-name` from the clicked trigger onto the
confirmation form's action and name placeholder before opening the modal —
needed because a single modal is shared across N table rows. Updated
`shared/_modal.html.erb` to accept an optional `data:` local so callers can
merge `data-confirm-delete-target="modal"` onto the overlay div.
`Dashboard::DeviceAttributesController#destroy`'s `close_modal` target was
corrected from the (colliding) generic `"confirm-delete-modal"` to
`"confirm-delete-attribute-modal"`. Also fixed a latent bug found by this
work: `show.html.erb` rendered `@device.device_attributes` via Rails' default
collection partial lookup, which looks for `_device_attribute.html.erb`
(doesn't exist) instead of the actual `_attribute.html.erb` partial — this was
previously masked because no spec exercised the show page with attributes
present; fixed via an explicit `render partial:` call.

---

### Task 6.2: Add button styling & disable during submit — [x] DONE

```erb
<!-- In device form & attribute form -->
<!-- <%= f.submit class: 'btn btn-primary', data: { disable_with: 'Guardando...' } %> -->
<!-- - Turbo automatically disables button + changes text during submission -->
```

**Testable**: Submit button disables & text changes during POST.

**Implementation note**: Already present on both `devices/_form.html.erb` and
`device_attributes/_form.html.erb` submit buttons since Phase 4/5 — verified,
no changes needed.

---

### Task 6.3: Create flash message partial (_flash.html.erb) — [x] DONE

```erb
<!-- app/views/shared/_flash.html.erb -->
<!-- Renders flash messages from session/Turbo Stream -->
<!-- Auto-dismiss after 3s using setTimeout -->
<!-- Styling: Bootstrap alert classes -->
```

**Testable**: Flash appears after action, disappears after 3s.

**Implementation note**: `_flash.html.erb` existed (Phase 4, minimal). Added
`data-controller="flash"` and a new `app/javascript/controllers/flash_controller.js`
that calls `setTimeout(() => this.element.remove(), 3000)` on connect (works
for both full-page-load flashes and Turbo Stream-inserted ones, since
Stimulus `connect()` fires on every DOM attach). Bootstrap `alert alert-<type>`
classes already applied (unstyled until Phase 8 adds the CDN, as expected).
Auto-dismiss timing is not covered by request specs — no JS test driver in
this repo (confirmed Phase 3) — flagged as manually-verifiable per task
instructions, not blocking.

---

### Task 6.4: Add routes for nested attributes — [x] DONE (pulled forward into Phase 5, hard dependency for nested CRUD to route at all)

```ruby
# config/routes.rb
# namespace :dashboard do
#   resources :devices do
#     resources :device_attributes, only: [:new, :create, :edit, :update, :destroy]
#   end
# end
```

**Testable**: All nested routes exist (GET/POST/PATCH/DELETE).

---

## Phase 7: Integration Tests (6 tasks) — [x] COMPLETE

**Why**: Verify 36 spec scenarios pass. Test CRUD via Capybara + Turbo.

**Implementation note**: Added a real JS-capable Capybara driver (Cuprite/Ferrum
headless Chromium, `spec/rails_helper.rb`) since none existed before — all 6
spec files below are genuine `type: :system` specs, not request specs.
Chromium installed in the final Docker stage (`Dockerfile`). Writing real
system specs surfaced several previously-undetectable bugs (no prior JS
driver existed to catch them), all fixed as part of this phase:

1. **Confirmed modal-trigger DOM-ancestor bug** (the reason this phase was
   scoped to use a real browser): "+Add Device"/"+Add Attribute" open-modal
   triggers used `data-action="click->modal#open"` while living OUTSIDE
   their target modal's `data-controller="modal"` element — Stimulus
   resolves actions via DOM ancestry, so the click silently did nothing.
   Fixed with a new `modal_trigger_controller.js` using a Stimulus **outlet**
   (`data-modal-trigger-modal-outlet="#device-modal"`) to reach across the
   DOM tree to the target modal's own controller and call `.open()`
   directly — the officially recommended Stimulus pattern for "trigger
   outside the controlled element's subtree". The "Edit attribute" trigger
   was intentionally left as a plain link (no JS), since `attribute-modal`
   only ever renders the *new*-attribute form — wiring `modal#open` there
   would have shown a blank form instead of the row's actual values.
2. **Bootstrap `.modal-backdrop` class collision**: the custom modal
   component's own `.modal-backdrop` div (click-outside-to-close) reused a
   class name Bootstrap's CSS (loaded globally via CDN) also defines with
   `position: fixed; inset: 0; z-index: 1050`, silently overlaying
   `.modal-content` and swallowing every click inside every modal. Fixed by
   resetting the class in `shared/_modal.html.erb`'s own `<style>` block.
3. **Missing `data-` prefix on modal extra-data attributes**: `_modal.html.erb`
   built extra `data-*` attributes via `tag.attributes(local_assigns[:data])`
   without prefixing keys, so `{ "confirm-delete-target": "modal" }` rendered
   as the literal (non-`data-`) attribute `confirm-delete-target="modal"`,
   which Stimulus never sees — the delete-confirmation modal's `.open` class
   was never applied. Fixed by prefixing keys before calling `tag.attributes`.
4. **Missing `Rack::MethodOverride`**: `config.api_only = true` drops it from
   the middleware stack. Every dashboard edit/update/destroy `<form>` submits
   PATCH/DELETE via the standard Rails `_method` hidden field (browsers can't
   send those verbs natively) — without the middleware, every such POST
   404'd. Invisible to request specs (they call `patch`/`delete` directly,
   bypassing the method-override mechanism entirely); only a real browser +
   form submission exercises it. Added back in `config/application.rb`
   alongside the already-manually-restored Cookies/Session middleware.
5. **`SessionsController#create` missing `status: :unprocessable_entity`**:
   the failed-login `render :new` had no explicit status (defaulting to 200).
   Turbo Drive only renders a POST form response's body in place when it's a
   redirect or a non-2xx status; a bare 200 re-render is silently ignored,
   leaving the old page displayed. Every other form controller in this app
   already used `:unprocessable_entity` for this reason — `SessionsController`
   was the one inconsistent holdout, only surfaced by a real Turbo-driven
   browser submission.
6. Added a `Logout` link to `application.html.erb` (visible when
   `logged_in?`) — required for spec 1.3 ("User can log out"); previously the
   `DELETE /logout` route existed but no UI element triggered it anywhere.
7. `DatabaseCleaner` (`:truncation` strategy) added for `type: :system` specs
   only: the JS driver runs the Rails app in a real Puma server thread with
   its own DB connection, invisible to the test thread's open transaction, so
   the normal `use_transactional_fixtures` rollback silently failed to clean
   up between system specs (symptom: `RecordInvalid: Email has already been
   taken` on the 2nd example). Non-system specs keep the fast transactional
   strategy.

### Task 7.1: Create login tests (spec/system/dashboard/login_spec.rb) — [x] DONE

```ruby
# - User can log in with valid credentials
# - User sees dashboard after login
# - Unauthenticated user redirected to /login
# - User can log out
```

**Testable**: Run RSpec, 4 tests pass.

---

### Task 7.2: Create devices list tests (spec/system/dashboard/devices/list_spec.rb) — [x] DONE

```ruby
# - List view shows all devices
# - Empty state when no devices
# - Links to view/edit/delete each device
# - "+ Add Device" button visible
```

**Testable**: Run RSpec, ~4 tests pass.

---

### Task 7.3: Create device create tests (spec/system/dashboard/devices/create_spec.rb) — [x] DONE

```ruby
# - Open "Add Device" modal
# - Fill form, submit
# - Device appears in list (no page reload)
# - Flash message shows "Device created"
# - Create with validation error shows error in modal
```

**Testable**: Run RSpec, ~5 tests pass.

---

### Task 7.4: Create device update tests (spec/system/dashboard/devices/update_spec.rb) — [x] DONE

```ruby
# - Open edit modal
# - Change field, submit
# - List row updates (no page reload)
# - Flash message shows "Device updated"
# - Validation error stays in modal
```

**Testable**: Run RSpec, ~4 tests pass.

---

### Task 7.5: Create device delete tests (spec/system/dashboard/devices/destroy_spec.rb) — [x] DONE

```ruby
# - Click delete button
# - Confirmation modal appears
# - Confirm: device removed from list, flash shows
# - Cancel: modal closes, device stays in list
```

**Testable**: Run RSpec, ~3 tests pass.

---

### Task 7.6: Create attribute CRUD tests (spec/system/dashboard/device_attributes_spec.rb) — [x] DONE

```ruby
# - Create attribute: modal form, row added to table
# - Update attribute: row updates (value changes)
# - Delete attribute: confirmation, row removed
# - Validation error: duplicate key rejected, error shown
```

**Testable**: Run RSpec, ~6 tests pass.

---

## Phase 8: Styling (3 tasks)

**Why**: Polish dashboard UI with Bootstrap + custom CSS.

### Task 8.1: Add Bootstrap CDN to layout — [x] DONE

```erb
<!-- app/views/layouts/application.html.erb -->
<!-- Head: <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet"> -->
<!-- Body end: <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script> -->
```

**Testable**: Page loads Bootstrap classes work (buttons, forms styled).

---

### Task 8.2: Style modal component (app/assets/stylesheets/modal.css) — [x] DONE

```css
/* .modal-overlay {} */
/* .modal-overlay.open {} */
/* .modal-content {} */
/* .modal-header {} */
/* .modal-body {} */
/* Animations: fade in/out, smooth transitions */
```

**Testable**: Modal appears/closes with smooth animation.

---

### Task 8.3: Style dashboard layout (app/assets/stylesheets/dashboard.css) — [x] DONE

```css
/* .dashboard-container {} */
/* .devices-table {} */
/* .attributes-table {} */
/* .empty-state {} */
/* Button styling, spacing, responsive adjustments */
```

**Testable**: Dashboard looks polished with Bootstrap + custom CSS.

---

## Phase 9: Error Handling & Edge Cases (3 tasks)

**Why**: Handle HTTP errors, network issues, edge cases gracefully.

### Task 9.1: Add 404 handling for deleted resources — [x] DONE

```ruby
# In Dashboard::DevicesController#show, edit, update, destroy
# before_action :set_device rescue_from ActiveRecord::RecordNotFound
# On not found: redirect to /dashboard/devices + flash "Device not found"
```

**Testable**: Access /dashboard/devices/999 → redirect + flash. 8 new request
specs (RED→GREEN), `rescue_from ActiveRecord::RecordNotFound` added to both
`Dashboard::DevicesController` (redirects to devices list, flash "Device not
found" — was previously falling through to `ApplicationController`'s global
`rescue_from`, which renders a JSON 404 body meant for the JWT API) and
`Dashboard::DeviceAttributesController` (redirects to the device page, flash
"Attribute not found", or to the devices list with "Device not found" if the
parent device itself is missing).

---

### Task 9.2: Handle validation errors from nested attributes — [x] DONE (already correct, no changes)

```ruby
# Dashboard::DeviceAttributesController#create
# API returns 422 "Key must be unique per device"
# Controller re-renders form with errors
# Turbo updates modal body with errors
```

**Testable**: Create duplicate attribute key → error shown in modal. Verified
already fully correct via the existing request spec ("does not create a
duplicate key and re-renders the form with errors") and system spec coverage
(`spec/system/dashboard/devices/create_spec.rb`, `device_attributes_spec.rb`)
— `render :new/:edit, status: :unprocessable_entity` + Turbo Drive's default
handling of non-2xx form responses already re-displays the form with errors
without a full page reload. No code changes needed.

---

### Task 9.3: Handle Turbo Stream errors (network failures) — [x] DONE (verified, no code changes)

```ruby
# If POST fails (network error, 500), Turbo doesn't clear form
# User can retry
# Maybe add error message "Failed to save, please try again"
```

**Testable**: Added a real headless-Chrome system spec
(`spec/system/dashboard/devices/server_error_spec.rb`) stubbing the create
action to return a genuine completed HTML 500 response, since a raw
unrescued `raise` in this app's in-process Cuprite/Puma test setup gets
re-raised into the test process by Capybara before Turbo Drive ever sees a
response — a testing-harness artifact, not real browser behavior. Verified
findings: (1) no device is persisted on a 500 — the failure never silently
"succeeds"; (2) on a genuine 500, Turbo Drive replaces the whole document
with the error response body (form state is lost from the DOM, matching
Turbo's documented non-2xx/non-turbo-stream handling — NOT preserved the way
422s are, since 422 preservation comes from the app deliberately re-rendering
the form, not from any Turbo-specific 500 safeguard); (3) true network drops
(no response ever arrives) are outside what Turbo Drive acts on at all — the
current page/form is left untouched by definition, since Turbo only mutates
the DOM upon receiving a response, but this specific sub-case remains
unverified by an automated test (undoable without a real dropped
connection). No code changes made: no obvious gap to patch — the 422 path
(expected/common failures) already works correctly, and true 500s produce a
clear, non-silent error state with no data loss, consistent with the rest of
the app's error handling.

---

## Phase 10: Polish & Cleanup (2 tasks)

**Why**: Final touches before archiving.

### Task 10.1: Add accessibility features — [x] DONE

```erb
<!-- form labels with for= -->
<!-- aria-labels for buttons -->
<!-- keyboard navigation: Tab through form, Enter to submit -->
<!-- modal: trap focus inside modal while open -->
```

**Testable**: Keyboard navigation works, screen reader-friendly.

**Result**: Form labels already used Rails' `f.label` helper across all
three dashboard forms (login, device, attribute), which auto-generates
matching `for=`/`id` pairs — no change needed there, verified by the
existing Capybara `fill_in`/`find_field` calls (label lookup) passing.
Row action links ("View"/"Edit"/"Delete") already carry visible text so
no icon-only-button aria-labels were needed; the modal's "x" close
button already had `aria-label="Close"`. Native Tab order was already
correct (no custom `tabindex`).

The real gap was focus management: `modal_controller.js` opened/closed
modals via `classList` only, with no focus trap and no return-focus
behavior, and the delete-confirmation modal bypassed `modal#open`
entirely (`confirm_delete_controller.js` toggled the `open` class
directly). Implemented:
- `modal_controller.js#open`: remembers the triggering element, moves
  focus to the first real form field (skipping the "x" close button),
  and attaches a keydown listener.
- `modal_controller.js#handleKeydown`: Escape closes the modal; Tab /
  Shift+Tab cycle focus within the modal's own focusable elements only
  (never escapes to the page behind it).
- `modal_controller.js#close` / `#closeViaStream`: remove the keydown
  listener and return focus to the element that opened the modal.
- `confirm_delete_controller.js`: now opens its modal via a Stimulus
  `modal` outlet (`this.modalOutlet.open(event)`) instead of touching
  `classList` directly, so the delete-confirmation dialogs get the same
  focus-trap / return-focus behavior as every other modal.

TDD: `spec/system/dashboard/accessibility_spec.rb` (5 real
Capybara/Cuprite system specs — actual browser focus/keyboard events,
no stubs) written first; 3 of 5 were already GREEN (native Tab order
already worked), 2 were RED (Escape-to-close, delete-modal focus trap)
until the JS changes above landed. All 5 GREEN after implementation.

---

### Task 10.2: Test in multiple browsers — [x] DONE (scope-limited)

```
- Chrome: check modal animation, form submission
- Firefox: check Stimulus controller, Turbo Stream
- Safari: check CSS animations, form behavior
- Edge: ensure compatibility
```

**Testable**: No visual/functional differences across browsers.

**Result**: This repo's Docker-based system-test setup only has headless
Chromium available (Cuprite/CDP) — no Firefox/Safari/Edge engine is
installed in the container, so those browsers were **not actually run**
and no fake "passing" specs were written for them (per explicit
instruction). What was done instead, honestly:
- Grepped `app/` for vendor-prefixed CSS (`-webkit-`, `-moz-`, `-ms-`),
  browser-sniffing (`navigator.*` beyond standard DOM), and
  `ActiveXObject`/similar non-standard APIs: **zero matches**. The app
  only uses Stimulus, Turbo (Hotwire), and Bootstrap 5 — all
  standards-based libraries designed for cross-browser support, plus
  plain DOM APIs (`classList`, `querySelectorAll`, `closest`, `focus`)
  supported by all evergreen browsers.
- Firefox/Safari/Edge verification is **explicitly out of scope** for
  this automated pass. It would require either a cross-browser cloud
  grid (BrowserStack/Sauce Labs) or manual verification on real
  browsers, neither of which is available in this environment.

---

## Summary: Task Breakdown

| Phase | Area | Task Count | Est. Time |
|-------|------|-----------|-----------|
| 1 | Session Auth | 5 | 1.5 hrs |
| 2 | Dashboard Home | 3 | 1 hr |
| 3 | Stimulus & Turbo | 3 | 1.5 hrs |
| 4 | Device CRUD | 9 | 3 hrs |
| 5 | Attribute CRUD | 6 | 2 hrs |
| 6 | Modal Integration | 4 | 1.5 hrs |
| 7 | Integration Tests | 6 | 2 hrs |
| 8 | Styling | 3 | 1.5 hrs |
| 9 | Error Handling | 3 | 1 hr |
| 10 | Polish | 2 | 0.5 hrs |
| **Total** | | **34 tasks** | **~15-16 hours** |

---

## Execution Notes

**Order**: Execute phases sequentially (1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10).

**Why sequential**: Each phase depends on prior phases:
- Auth (1) needed before dashboard (2)
- Stimulus (3) foundation for modals in CRUD (4-5)
- CRUD (4-5) tested by tests (7)
- Base styling (8) last, won't block functionality

**Testing strategy**:
- TDD: write spec for each task, code to pass spec
- Don't skip tests; they catch integration issues
- Use `rails test:system` for Capybara + Turbo tests

**Commits**: Commit per phase group (every 5-6 tasks) to maintain clean git history.

---

## Teaching Points per Phase

**Phase 1 (Auth)**: Rails sessions (httpOnly cookies, automatic, secure). How Rails sets/reads `session[:user_id]`.

**Phase 2 (Home)**: Rails layout (application.html.erb shared by all views). Navigation after login.

**Phase 3 (Stimulus)**: Reusable JavaScript controllers. Managing UI state (open/close). Turbo Stream custom actions.

**Phase 4 (Device CRUD)**: Full resource lifecycle (index, new, create, show, edit, update, destroy). Turbo form submissions.

**Phase 5 (Attribute CRUD)**: Nested resources (`/devices/:device_id/attributes`). Partial views for modals. Strong params.

**Phase 6 (Modals)**: Reusable component pattern. Form state management. Confirmation dialogs.

**Phase 7 (Tests)**: Integration testing with Capybara + Turbo. No page reloads (check DOM updates, not new pages).

**Phase 8 (Styling)**: Bootstrap + custom CSS. Modal animations. Responsive design.

**Phase 9 (Errors)**: Graceful error handling. Validation feedback. Network resilience.

**Phase 10 (Polish)**: Accessibility. Cross-browser testing. Final UX review.

---

## Ready for APPLY Phase

Once confirmed, execute these 34 tasks in order:

1. Write spec/test for task
2. Implement to pass spec
3. Commit per phase
4. Move to next task

Expected: 15-16 hours of focused development.

Next: APPLY phase begins execution.
