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

## Phase 3: Stimulus Modal Controller & Integration (3 tasks)

**Why**: Modal interactivity foundation for all CRUD. Build reusable component first.

### Task 3.1: Create Stimulus modal controller (app/javascript/controllers/modal_controller.js)

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

### Task 3.2: Create shared modal component (_modal.html.erb)

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

### Task 3.3: Create custom Turbo Stream action for closing modals

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

## Phase 4: Devices List & CRUD Views (10 tasks)

**Why**: Core dashboard feature. Build list view first, then forms.

### Task 4.1: Create Dashboard::DevicesController

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

### Task 4.2: Create devices list view (dashboard/devices/index.html.erb)

```erb
<!-- Simplified version (full view in task 4.3) -->
<!-- - Header: "Your Devices" + "+ Add New Device" button -->
<!-- - Table: name, type, status, actions columns -->
<!-- - Each row: render 'device' partial -->
<!-- - Empty state: "You have no devices yet" with link to add -->
```

**Testable**: Page renders list of devices, empty state shows when no devices.

---

### Task 4.3: Create device card partial (dashboard/devices/_device.html.erb)

```erb
<!-- app/views/dashboard/devices/_device.html.erb -->
<!-- - Table row (id="device-<%= device.id %>") -->
<!-- - Name, type, status columns -->
<!-- - Action buttons: [View] [Edit] [Delete] -->
<!-- - Edit & Delete buttons use data-turbo-method, data-action -->
```

**Testable**: Each device renders as table row with action buttons.

---

### Task 4.4: Create device new form modal (dashboard/devices/new.html.erb)

```erb
<!-- app/views/dashboard/devices/new.html.erb -->
<!-- render 'shared/modal', id: 'device-modal', title: 'Add Device' do -->
<!--   render 'form', device: @device (or Device.new) -->
<!-- end -->
```

**Testable**: GET /dashboard/devices/new renders modal with form.

---

### Task 4.5: Create device form partial (dashboard/devices/_form.html.erb)

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

### Task 4.6: Implement create action (POST /dashboard/devices)

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

### Task 4.7: Create device show view (dashboard/devices/show.html.erb)

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

### Task 4.8: Implement update action (PATCH /dashboard/devices/:id)

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

### Task 4.9: Implement delete action (DELETE /dashboard/devices/:id)

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

### Task 5.1: Create Dashboard::DeviceAttributesController

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

### Task 5.2: Create attributes list row partial (dashboard/device_attributes/_attribute.html.erb)

```erb
<!-- app/views/dashboard/device_attributes/_attribute.html.erb -->
<!-- Table row (id="attribute-<%= attribute.id %>") -->
<!-- Columns: key, value, updated_at, actions -->
<!-- Action buttons: [Edit] [Delete] -->
```

**Testable**: Attribute renders as table row.

---

### Task 5.3: Create attribute form partial (dashboard/device_attributes/_form.html.erb)

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

### Task 5.4: Implement attribute create action (POST /v1/devices/:device_id/device_attributes)

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

### Task 5.5: Implement attribute update action (PATCH)

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

### Task 5.6: Implement attribute delete action (DELETE)

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

### Task 6.1: Create delete confirmation modals for devices & attributes

```erb
<!-- app/views/dashboard/devices/_delete_confirmation.html.erb -->
<!-- Prompt: "Are you sure?" + device name -->
<!-- Two buttons: [Confirm Delete] [Cancel] -->
<!-- Confirm button: form POST with method: delete -->
<!-- Cancel button: data-action="click->modal#close" -->
```

**Testable**: Click delete → modal shows → confirm/cancel buttons work.

---

### Task 6.2: Add button styling & disable during submit

```erb
<!-- In device form & attribute form -->
<!-- <%= f.submit class: 'btn btn-primary', data: { disable_with: 'Guardando...' } %> -->
<!-- - Turbo automatically disables button + changes text during submission -->
```

**Testable**: Submit button disables & text changes during POST.

---

### Task 6.3: Create flash message partial (_flash.html.erb)

```erb
<!-- app/views/shared/_flash.html.erb -->
<!-- Renders flash messages from session/Turbo Stream -->
<!-- Auto-dismiss after 3s using setTimeout -->
<!-- Styling: Bootstrap alert classes -->
```

**Testable**: Flash appears after action, disappears after 3s.

---

### Task 6.4: Add routes for nested attributes

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

## Phase 7: Integration Tests (6 tasks)

**Why**: Verify 36 spec scenarios pass. Test CRUD via Capybara + Turbo.

### Task 7.1: Create login tests (spec/system/dashboard/login_spec.rb)

```ruby
# - User can log in with valid credentials
# - User sees dashboard after login
# - Unauthenticated user redirected to /login
# - User can log out
```

**Testable**: Run RSpec, 4 tests pass.

---

### Task 7.2: Create devices list tests (spec/system/dashboard/devices/list_spec.rb)

```ruby
# - List view shows all devices
# - Empty state when no devices
# - Links to view/edit/delete each device
# - "+ Add Device" button visible
```

**Testable**: Run RSpec, ~4 tests pass.

---

### Task 7.3: Create device create tests (spec/system/dashboard/devices/create_spec.rb)

```ruby
# - Open "Add Device" modal
# - Fill form, submit
# - Device appears in list (no page reload)
# - Flash message shows "Device created"
# - Create with validation error shows error in modal
```

**Testable**: Run RSpec, ~5 tests pass.

---

### Task 7.4: Create device update tests (spec/system/dashboard/devices/update_spec.rb)

```ruby
# - Open edit modal
# - Change field, submit
# - List row updates (no page reload)
# - Flash message shows "Device updated"
# - Validation error stays in modal
```

**Testable**: Run RSpec, ~4 tests pass.

---

### Task 7.5: Create device delete tests (spec/system/dashboard/devices/destroy_spec.rb)

```ruby
# - Click delete button
# - Confirmation modal appears
# - Confirm: device removed from list, flash shows
# - Cancel: modal closes, device stays in list
```

**Testable**: Run RSpec, ~3 tests pass.

---

### Task 7.6: Create attribute CRUD tests (spec/system/dashboard/device_attributes_spec.rb)

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

### Task 8.1: Add Bootstrap CDN to layout

```erb
<!-- app/views/layouts/application.html.erb -->
<!-- Head: <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet"> -->
<!-- Body end: <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script> -->
```

**Testable**: Page loads Bootstrap classes work (buttons, forms styled).

---

### Task 8.2: Style modal component (app/assets/stylesheets/modal.css)

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

### Task 8.3: Style dashboard layout (app/assets/stylesheets/dashboard.css)

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

### Task 9.1: Add 404 handling for deleted resources

```ruby
# In Dashboard::DevicesController#show, edit, update, destroy
# before_action :set_device rescue_from ActiveRecord::RecordNotFound
# On not found: redirect to /dashboard/devices + flash "Device not found"
```

**Testable**: Access /dashboard/devices/999 → redirect + flash.

---

### Task 9.2: Handle validation errors from nested attributes

```ruby
# Dashboard::DeviceAttributesController#create
# API returns 422 "Key must be unique per device"
# Controller re-renders form with errors
# Turbo updates modal body with errors
```

**Testable**: Create duplicate attribute key → error shown in modal.

---

### Task 9.3: Handle Turbo Stream errors (network failures)

```ruby
# If POST fails (network error, 500), Turbo doesn't clear form
# User can retry
# Maybe add error message "Failed to save, please try again"
```

**Testable**: Simulate network error → form not cleared → user can retry.

---

## Phase 10: Polish & Cleanup (2 tasks)

**Why**: Final touches before archiving.

### Task 10.1: Add accessibility features

```erb
<!-- form labels with for= -->
<!-- aria-labels for buttons -->
<!-- keyboard navigation: Tab through form, Enter to submit -->
<!-- modal: trap focus inside modal while open -->
```

**Testable**: Keyboard navigation works, screen reader-friendly.

---

### Task 10.2: Test in multiple browsers

```
- Chrome: check modal animation, form submission
- Firefox: check Stimulus controller, Turbo Stream
- Safari: check CSS animations, form behavior
- Edge: ensure compatibility
```

**Testable**: No visual/functional differences across browsers.

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
