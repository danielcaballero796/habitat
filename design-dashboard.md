# Design: Device Dashboard with Modal-Based CRUD

**Change ID**: `2026-08-04-device-dashboard`  
**Status**: DESIGN phase  
**Created**: 2026-08-04  
**UI Pattern**: Modal dialogs for all forms + custom modal confirmations (no Turbo's native data-turbo-confirm)

This document defines the technical architecture, controller structure, view hierarchy, Turbo Stream patterns, and Stimulus interactivity for the dashboard.

---

## Why Modals for This Project

**User Decision**: Polished, consistent modal-based UI pattern throughout (create forms, edit forms, delete confirmations). No mixing native browser dialogs with custom modals.

**Benefits**:
- **Consistency**: All interactions (forms + confirmations) use the same modal component
- **Polish**: Custom CSS allows branded, smooth animations
- **Control**: Stimulus controller manages modal lifecycle (open, close, error handling)
- **UX**: No page flashes; all interactions are contained within modal overlay

**Cost**:
- More JavaScript (Stimulus modal controller)
- More HTML (modal wrapper component)
- But simpler than separate implementations per form

**Teaching Value**:
- Introduces Stimulus.js (Rails' lightweight JavaScript framework)
- Shows reusable component patterns (DRY principle in frontend)
- Demonstrates Turbo + Stimulus integration (modern Rails)

---

## Architecture Overview

### Layers

```
Rails App (Monolith)
├── API Layer (unchanged)
│   ├── V1::DevicesController (JSON, JWT auth)
│   ├── V1::DeviceAttributesController (JSON, JWT auth)
│   └── Models: Device, DeviceAttribute, User
│
├── Dashboard Layer (NEW)
│   ├── SessionsController (login/logout)
│   ├── DashboardController (home page)
│   ├── Dashboard::DevicesController (list, new, edit, delete)
│   ├── Dashboard::DeviceAttributesController (new, edit, delete)
│   ├── Views: ERB templates with modals
│   └── Stimulus Controllers: ModalController (reusable)
│
└── Database (unchanged)
    ├── users, devices, device_attributes tables
    └── All existing migrations
```

### Request-Response Pattern (Turbo + Modals)

```
Browser (Dashboard Page)
  ↓ User clicks "Add Device" button
  ↓ JS event → Stimulus ModalController.open()
  ↓ (modal HTML already in page from previous render)
  ↓ Modal overlay + form appears (no HTTP request yet!)
  
  ↓ User fills form, submits
  ↓ Form action: POST /dashboard/devices (Turbo form)
  ↓ No page reload (Turbo intercepts)
  
  ↓ Server processes POST /dashboard/devices
    ├─ If valid: render response with Turbo Stream
    │  ├─ Turbo Stream #1: close modal via JS
    │  ├─ Turbo Stream #2: prepend new device row to devices list
    │  ├─ Turbo Stream #3: show flash message
    │
    └─ If invalid (validation error):
       ├─ Render modal partial with errors
       └─ Turbo replaces modal body with form + errors (modal stays open)

Browser updates dynamically (no refresh)
```

---

## Controller Structure

### SessionsController (NEW)

**Purpose**: Session-based authentication (separate from JWT API)

```ruby
# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  skip_before_action :verify_jwt  # Sessions don't use JWT
  
  def new
    # GET /login → render login form
    render :new
  end
  
  def create
    # POST /login → authenticate, set session
    user = User.find_by(email: params[:email])
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: "Logged in successfully"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new
    end
  end
  
  def destroy
    # DELETE /logout (or GET for simplicity)
    session.delete(:user_id)
    redirect_to login_path, notice: "Logged out"
  end
end
```

**Routes**:
```ruby
get '/login', to: 'sessions#new'
post '/login', to: 'sessions#create'
delete '/logout', to: 'sessions#destroy'
```

---

### DashboardController (NEW)

**Purpose**: Dashboard home page, current_user helper

```ruby
# app/controllers/dashboard_controller.rb
class DashboardController < ApplicationController
  skip_before_action :verify_jwt  # Dashboard uses sessions
  before_action :require_login
  
  def index
    # GET /dashboard → home page with device list
    @devices = Device.all
    render :index
  end
  
  private
  
  def require_login
    redirect_to login_path unless current_user
  end
  
  helper_method :current_user
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
end
```

**Routes**:
```ruby
get '/dashboard', to: 'dashboard#index'
```

---

### Dashboard::DevicesController (NEW)

**Purpose**: Dashboard CRUD for devices (forms + Turbo responses)

```ruby
# app/controllers/dashboard/devices_controller.rb
module Dashboard
  class DevicesController < DashboardController
    before_action :set_device, only: [:show, :edit, :update, :destroy]
    
    def index
      # GET /dashboard/devices → list view
      @devices = Device.all
      render :index
    end
    
    def new
      # GET /dashboard/devices/new → modal form (empty device)
      @device = Device.new
      render :new, layout: false  # Render partial only (modal content)
    end
    
    def create
      # POST /dashboard/devices → create via Turbo form
      @device = Device.new(device_params)
      
      if @device.save
        # Success: close modal + update devices list
        render turbo_stream: [
          turbo_stream.action(:close_modal, "#device-modal"),
          turbo_stream.prepend('devices-list', partial: 'dashboard/devices/device', locals: { device: @device }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { message: 'Device created successfully' })
        ]
      else
        # Validation error: re-render form with errors (modal stays open)
        render :new, status: :unprocessable_entity, layout: false
      end
    end
    
    def show
      # GET /dashboard/devices/:id → detail view with nested attributes
      render :show
    end
    
    def edit
      # GET /dashboard/devices/:id/edit → modal form (pre-filled device)
      render :edit, layout: false  # Render partial only
    end
    
    def update
      # PATCH /dashboard/devices/:id → update via Turbo form
      if @device.update(device_params)
        # Success: close modal + update device in list
        render turbo_stream: [
          turbo_stream.action(:close_modal, "#device-modal"),
          turbo_stream.replace("device-#{@device.id}", partial: 'dashboard/devices/device', locals: { device: @device }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { message: 'Device updated successfully' })
        ]
      else
        # Validation error: re-render form with errors
        render :edit, status: :unprocessable_entity, layout: false
      end
    end
    
    def destroy
      # DELETE /dashboard/devices/:id → delete via Turbo request
      @device.destroy
      
      render turbo_stream: [
        turbo_stream.action(:close_modal, "#confirm-delete-modal"),
        turbo_stream.remove("device-#{@device.id}"),
        turbo_stream.update('flash', partial: 'shared/flash', locals: { message: 'Device deleted successfully' })
      ]
    end
    
    private
    
    def set_device
      @device = Device.find(params[:id])
    end
    
    def device_params
      params.require(:device).permit(:name, :type, :brand, :model, :room, :status, :ip_address, :mac_address, :firmware_version, :purchase_date, :notes)
    end
  end
end
```

**Routes**:
```ruby
namespace :dashboard do
  resources :devices do
    resources :device_attributes, only: [:new, :create, :edit, :update, :destroy]
  end
end
```

---

### Dashboard::DeviceAttributesController (NEW)

**Purpose**: Nested CRUD for device attributes (forms within device detail modal)

```ruby
# app/controllers/dashboard/device_attributes_controller.rb
module Dashboard
  class DeviceAttributesController < DashboardController
    before_action :set_device
    before_action :set_attribute, only: [:edit, :update, :destroy]
    
    def new
      # GET /dashboard/devices/:device_id/device_attributes/new → modal form
      @attribute = @device.device_attributes.new
      render :new, layout: false
    end
    
    def create
      # POST /dashboard/devices/:device_id/device_attributes → create via Turbo
      @attribute = @device.device_attributes.new(attribute_params)
      
      if @attribute.save
        # Success: add attribute row to table, close modal
        render turbo_stream: [
          turbo_stream.action(:close_modal, "#attribute-modal"),
          turbo_stream.append("attributes-list", partial: 'dashboard/device_attributes/attribute', locals: { attribute: @attribute }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { message: 'Attribute added successfully' })
        ]
      else
        # Validation error: re-render form with errors
        render :new, status: :unprocessable_entity, layout: false
      end
    end
    
    def edit
      # GET /dashboard/devices/:device_id/device_attributes/:id/edit → modal form
      render :edit, layout: false
    end
    
    def update
      # PATCH /dashboard/devices/:device_id/device_attributes/:id → update via Turbo
      if @attribute.update(attribute_params)
        # Success: update attribute row in table, close modal
        render turbo_stream: [
          turbo_stream.action(:close_modal, "#attribute-modal"),
          turbo_stream.replace("attribute-#{@attribute.id}", partial: 'dashboard/device_attributes/attribute', locals: { attribute: @attribute }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { message: 'Attribute updated successfully' })
        ]
      else
        # Validation error: re-render form
        render :edit, status: :unprocessable_entity, layout: false
      end
    end
    
    def destroy
      # DELETE /dashboard/devices/:device_id/device_attributes/:id → delete via Turbo
      @attribute.destroy
      
      render turbo_stream: [
        turbo_stream.action(:close_modal, "#confirm-delete-modal"),
        turbo_stream.remove("attribute-#{@attribute.id}"),
        turbo_stream.update('flash', partial: 'shared/flash', locals: { message: 'Attribute deleted successfully' })
      ]
    end
    
    private
    
    def set_device
      @device = Device.find(params[:device_id])
    end
    
    def set_attribute
      @attribute = @device.device_attributes.find(params[:id])
    end
    
    def attribute_params
      params.require(:device_attribute).permit(:key, :value)
    end
  end
end
```

---

## View Structure

### Reusable Modal Component

```erb
<!-- app/views/shared/_modal.html.erb -->
<div id="<%= id %>" class="modal-overlay" data-controller="modal">
  <div class="modal-backdrop" data-action="click->modal#closeOnBackdrop"></div>
  <div class="modal-content">
    <div class="modal-header">
      <h2><%= title %></h2>
      <button type="button" class="modal-close" data-action="click->modal#close">
        &times;
      </button>
    </div>
    <div class="modal-body">
      <%= content %>
    </div>
  </div>
</div>

<style>
  .modal-overlay {
    display: none;
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    z-index: 1000;
  }
  
  .modal-overlay.open {
    display: flex;
    align-items: center;
    justify-content: center;
  }
  
  .modal-content {
    background: white;
    border-radius: 8px;
    box-shadow: 0 20px 25px rgba(0, 0, 0, 0.15);
    width: 90%;
    max-width: 500px;
    max-height: 90vh;
    overflow-y: auto;
  }
  
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 20px;
    border-bottom: 1px solid #e5e7eb;
  }
  
  .modal-close {
    background: none;
    border: none;
    font-size: 28px;
    cursor: pointer;
    color: #6b7280;
  }
  
  .modal-body {
    padding: 20px;
  }
</style>
```

**Usage in views**:
```erb
<%= render 'shared/modal', id: 'device-modal', title: 'Add Device' do %>
  <%= render 'form', device: @device %>
<% end %>
```

---

### Stimulus Modal Controller

```javascript
// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Opens the modal and focuses the first form input
  open(event) {
    event?.preventDefault()
    this.element.classList.add("open")
    this.element.querySelector("input:first-of-type")?.focus()
  }
  
  // Closes the modal
  close(event) {
    event?.preventDefault()
    this.element.classList.remove("open")
    this.resetForm()
  }
  
  // Close when user clicks backdrop (outside modal)
  closeOnBackdrop(event) {
    if (event.target.classList.contains("modal-backdrop")) {
      this.close()
    }
  }
  
  // Close modal (called from Turbo Stream)
  closeViaStream() {
    this.element.classList.remove("open")
    this.resetForm()
  }
  
  // Reset form to clear validation errors
  resetForm() {
    const form = this.element.querySelector("form")
    if (form) {
      form.reset()
      // Clear error classes/messages
      form.querySelectorAll(".field_with_errors").forEach(field => {
        field.classList.remove("field_with_errors")
      })
    }
  }
}
```

**How it's called**:
```erb
<!-- Open modal on button click -->
<button data-action="click->modal#open" data-modal-target="trigger">
  Add Device
</button>

<!-- Turbo Stream closes modal from server -->
turbo_stream.action(:close_modal, "#device-modal")
  → triggers custom Turbo Stream action that calls modal#closeViaStream
```

---

### Devices List View

```erb
<!-- app/views/dashboard/devices/index.html.erb -->
<div class="dashboard-container">
  <header class="dashboard-header">
    <h1>Your Devices</h1>
    <button class="btn btn-primary" data-action="click->modal#open">
      + Add New Device
    </button>
  </header>
  
  <div id="flash"></div>
  
  <div id="devices-list" class="devices-table">
    <% if @devices.any? %>
      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Type</th>
            <th>Status</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          <% @devices.each do |device| %>
            <%= render 'device', device: device %>
          <% end %>
        </tbody>
      </table>
    <% else %>
      <p class="empty-state">You have no devices yet. <%= link_to 'Add one', '#', data: { action: 'click->modal#open' } %></p>
    <% end %>
  </div>
  
  <!-- Modals (hidden until opened) -->
  <%= render 'shared/modal', id: 'device-modal', title: 'Add Device' do %>
    <%= render 'form', device: @device || Device.new %>
  <% end %>
  
  <%= render 'shared/modal', id: 'confirm-delete-modal', title: 'Confirm Delete' do %>
    <%= render 'delete_confirmation' %>
  <% end %>
</div>
```

### Device Card Partial

```erb
<!-- app/views/dashboard/devices/_device.html.erb -->
<tr id="device-<%= device.id %>">
  <td><strong><%= device.name %></strong></td>
  <td><%= device.type %></td>
  <td>
    <span class="badge badge-<%= device.status %>">
      <%= device.status %>
    </span>
  </td>
  <td class="actions">
    <%= link_to 'View', device_path(device), class: 'btn btn-sm btn-secondary' %>
    
    <%= button_to 'Edit', 
        edit_dashboard_device_path(device), 
        method: :get, 
        class: 'btn btn-sm btn-warning',
        data: { action: 'click->modal#open', remote: true } %>
    
    <%= button_to 'Delete', 
        dashboard_device_path(device), 
        method: :delete, 
        class: 'btn btn-sm btn-danger',
        data: { action: 'click->confirm-modal#show', confirm_target: '#confirm-delete-modal' } %>
  </td>
</tr>
```

**Why Turbo intercepts these links**:
- GET link intercepts → fetches partial, Turbo inserts into modal
- PATCH form intercepts → Turbo Stream response with close + DOM update
- DELETE link intercepts → custom Turbo handler shows confirm modal

---

### Device Detail View

```erb
<!-- app/views/dashboard/devices/show.html.erb -->
<div class="device-detail">
  <div class="detail-header">
    <h1><%= @device.name %></h1>
    <div class="actions">
      <%= link_to 'Back', dashboard_devices_path, class: 'btn btn-secondary' %>
      <%= button_to 'Edit', edit_dashboard_device_path(@device), method: :get, class: 'btn btn-warning' %>
      <%= button_to 'Delete', dashboard_device_path(@device), method: :delete, class: 'btn btn-danger' %>
    </div>
  </div>
  
  <div class="detail-body">
    <div class="device-info">
      <p><strong>Type:</strong> <%= @device.type %></p>
      <p><strong>Brand:</strong> <%= @device.brand %></p>
      <p><strong>Model:</strong> <%= @device.model %></p>
      <p><strong>Room:</strong> <%= @device.room %></p>
      <p><strong>Status:</strong> <%= @device.status %></p>
      <p><strong>IP Address:</strong> <%= @device.ip_address %></p>
      <p><strong>MAC Address:</strong> <%= @device.mac_address %></p>
      <p><strong>Firmware:</strong> <%= @device.firmware_version %></p>
      <p><strong>Notes:</strong> <%= @device.notes %></p>
    </div>
    
    <div class="attributes-section">
      <div class="attributes-header">
        <h3>Device Attributes</h3>
        <%= button_to '+ Add Attribute', 
            new_dashboard_device_device_attribute_path(@device), 
            method: :get, 
            class: 'btn btn-sm btn-primary',
            data: { remote: true, action: 'click->modal#open' } %>
      </div>
      
      <% if @device.device_attributes.any? %>
        <table id="attributes-list" class="attributes-table">
          <thead>
            <tr>
              <th>Key</th>
              <th>Value</th>
              <th>Updated</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            <% @device.device_attributes.each do |attr| %>
              <%= render 'dashboard/device_attributes/attribute', attribute: attr %>
            <% end %>
          </tbody>
        </table>
      <% else %>
        <p class="empty-state">No attributes yet.</p>
      <% end %>
    </div>
  </div>
  
  <!-- Modals -->
  <%= render 'shared/modal', id: 'attribute-modal', title: 'Add Attribute' do %>
    <%= render 'dashboard/device_attributes/form', device: @device, attribute: @device.device_attributes.new %>
  <% end %>
  
  <%= render 'shared/modal', id: 'confirm-delete-modal', title: 'Confirm Delete' do %>
    <%= render 'delete_confirmation' %>
  <% end %>
</div>
```

---

## Turbo Stream Actions (Custom)

Rails provides `turbo_stream.update`, `turbo_stream.replace`, etc. We need a custom action for closing modals:

```ruby
# config/importmap.rb
pin "controllers/turbo-stream-actions", to: "controllers/turbo_stream_actions.js"

# app/javascript/controllers/turbo_stream_actions.js
Turbo.StreamActions.close_modal = function() {
  const modalId = this.getAttribute("targets")
  const modal = document.querySelector(modalId)
  if (modal) {
    const controller = Stimulus.application.getControllerForElementAndIdentifier(modal, "modal")
    controller?.closeViaStream()
  }
}
```

**Usage in controller**:
```ruby
render turbo_stream: turbo_stream.action(:close_modal, "#device-modal")
```

---

## Authentication Flow (Sessions vs JWT)

```
Login Page (SessionsController):
  1. GET /login → show login form (ERB)
  2. POST /login → SessionsController#create
  3. If valid: set session[:user_id] (httpOnly cookie)
  4. Redirect to /dashboard

Dashboard (DashboardController):
  1. GET /dashboard → requires_login (checks session[:user_id])
  2. All views use @current_user from session
  3. No JWT tokens involved

API Clients (V1::DevicesController):
  1. POST /v1/login → JWT token in response (unchanged)
  2. GET /v1/devices with "Authorization: Bearer <token>"
  3. JWT auth middleware verifies token (unchanged)

Separation:
  - Dashboard: session cookie (browser automatic, secure)
  - API: JWT token (external clients, stateless)
  - Same User model, different auth mechanisms
```

---

## File Structure (After Implementation)

```
app/
├── controllers/
│   ├── sessions_controller.rb              [NEW]
│   ├── dashboard_controller.rb             [NEW]
│   ├── dashboard/
│   │   ├── devices_controller.rb           [NEW]
│   │   └── device_attributes_controller.rb [NEW]
│   ├── v1/
│   │   ├── devices_controller.rb           [unchanged]
│   │   └── device_attributes_controller.rb [unchanged]
│
├── views/
│   ├── layouts/
│   │   └── application.html.erb
│   ├── sessions/
│   │   └── new.html.erb                    [NEW]
│   ├── dashboard/
│   │   ├── index.html.erb                  [NEW]
│   │   ├── devices/
│   │   │   ├── index.html.erb              [NEW]
│   │   │   ├── show.html.erb               [NEW]
│   │   │   ├── new.html.erb (modal)        [NEW]
│   │   │   ├── edit.html.erb (modal)       [NEW]
│   │   │   ├── _form.html.erb              [NEW]
│   │   │   ├── _device.html.erb            [NEW]
│   │   │   └── _delete_confirmation.html.erb [NEW]
│   │   └── device_attributes/
│   │       ├── new.html.erb (modal)        [NEW]
│   │       ├── edit.html.erb (modal)       [NEW]
│   │       ├── _form.html.erb              [NEW]
│   │       ├── _attribute.html.erb         [NEW]
│   │       └── _delete_confirmation.html.erb [NEW]
│   └── shared/
│       ├── _modal.html.erb                 [NEW]
│       └── _flash.html.erb                 [NEW]
│
├── javascript/
│   └── controllers/
│       ├── modal_controller.js             [NEW]
│       └── turbo_stream_actions.js         [NEW]
│
└── models/ [unchanged]
    ├── user.rb
    ├── device.rb
    └── device_attribute.rb
```

---

## Routes (Complete)

```ruby
# config/routes.rb

# API routes (unchanged)
namespace :v1 do
  post :login, to: 'login#login'
  resources :devices do
    resources :device_attributes, only: [:index, :create, :update, :destroy]
  end
end

# Session auth (NEW)
get '/login', to: 'sessions#new'
post '/login', to: 'sessions#create'
delete '/logout', to: 'sessions#destroy'

# Dashboard (NEW)
get '/dashboard', to: 'dashboard#index'
namespace :dashboard do
  resources :devices do
    resources :device_attributes, only: [:new, :create, :edit, :update, :destroy]
  end
end
```

---

## Summary: Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| **Modal-based CRUD** | User wants polished, consistent UI; modals provide that |
| **Reusable Stimulus modal controller** | DRY principle; one controller handles open/close for all modals |
| **Session-based auth for dashboard** | Simpler than JWT for browser UI; httpOnly cookies are secure |
| **JWT unchanged for API** | Maintains compatibility with external clients |
| **Turbo Stream responses** | Partial HTML from server, Turbo inserts into DOM (no page reload) |
| **Partial views for forms** | `render layout: false` for modal content (no outer HTML wrapper) |
| **Custom Turbo Stream action** | `close_modal` action integrates Stimulus modal with Turbo Stream |
| **Bootstrap CDN** | Quick styling without build pipeline |

---

## Key Teaching Moments

1. **Stimulus Controllers**: Reusable JavaScript classes that manage DOM state (open/close modals). More organized than inline `<script>` tags.

2. **Turbo Streams**: Server renders partials as HTML, Turbo inserts/replaces in DOM. Combines server-side rendering (safety, simplicity) with client-side interactivity (no page flashes).

3. **Nested Resources in Views**: Dashboard mirrors API structure (`/devices/:device_id/device_attributes`). Consistency between UI and API layers.

4. **Session vs JWT**: Two different auth mechanisms in same app. Sessions for state-based (browser), JWT for stateless (API). Each suited to its use case.

5. **DRY in Frontend**: Modal component + controller reused across all CRUD operations. Same pattern for create, edit, delete forms.

---

## Clarifications Before TASKS Phase

1. ✓ Modal UX pattern confirmed
2. ✓ Auto-close forms after ~1s (success feedback visible)
3. ✓ Custom modal confirmations (consistent UI)
4. ✓ API error handling for validation (no duplicate key pre-check)
5. ❓ **Flash message styling**: 
   - Should flash auto-dismiss after 3s, or require manual close?
   - Recommendation: Auto-dismiss after 3s (standard UX)

6. ❓ **Form submission button states**:
   - Should "Create" button be disabled while submitting (prevent double-submit)?
   - Recommendation: Yes, disable + show loading text (standard practice)

7. ❓ **Empty device list state**:
   - Should empty state message have a direct link to "Add Device" button?
   - Recommendation: Yes, link opens modal directly (better UX)

Confirm these minor UX details, then we proceed to TASKS phase with 25-35 concrete implementation tasks.

---

## Next: TASKS Phase

Once you confirm the UX clarifications above, I'll break this design into:

**Phase 4 Tasks** (~25-35 tasks across these groups):
1. SessionsController + login views (2-3 tasks)
2. DashboardController + home page (2-3 tasks)
3. Dashboard::DevicesController + views (8-10 tasks)
4. Dashboard::DeviceAttributesController + views (6-8 tasks)
5. Stimulus modal controller + Turbo integration (3-4 tasks)
6. Integration tests (Capybara + Turbo specs) (3-4 tasks)
7. CSS styling (modal, layout, responsive base) (2-3 tasks)

Each task will be concrete ("Create `modal_controller.js` with open/close actions") and testable.

Then: APPLY (code writing) → VERIFY (tests) → ARCHIVE (documentation).
