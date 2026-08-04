# Specs: Device Dashboard with Full CRUD Operations

**Change ID**: `2026-08-04-device-dashboard`  
**Status**: SPEC phase  
**Created**: 2026-08-04  
**Scope**: Full CRUD dashboard (devices + nested device attributes)

This document defines behavioral requirements for the dashboard UI using Turbo/Hotwire. Each scenario uses Given/When/Then format and will be testable via Rails integration specs (Capybara + Turbo support).

---

## Capability 1: Dashboard Authentication & Home Page

The dashboard requires session-based login (separate from JWT API auth).

### Scenario 1.1: User can log in via dashboard login form

```gherkin
Given no user is logged in
And the dashboard login page is accessed (GET /login)
When the user submits email "admin@habitat.local" and password "secure123"
Then the session cookie is set with user_id
And the browser is redirected to /dashboard
And the welcome message "Welcome, admin@habitat.local" is displayed
```

**Why this test?** Dashboard needs session-based auth (separate from JWT API). User enters credentials, server sets httpOnly session cookie, browser is authenticated for subsequent requests.

**RSpec Integration Test Outline**:
```ruby
visit '/login'
fill_in 'Email', with: 'admin@habitat.local'
fill_in 'Password', with: 'secure123'
click_button 'Log In'
expect(page).to have_content 'Welcome, admin@habitat.local'
expect(page).to have_current_path '/dashboard'
```

---

### Scenario 1.2: Dashboard requires login

```gherkin
Given no user is logged in
When GET /dashboard is accessed
Then the browser is redirected to /login
And the dashboard content is NOT visible
```

**Why this test?** All dashboard routes are protected; unauthenticated users can't access them.

---

### Scenario 1.3: User can log out

```gherkin
Given a user is logged in (session exists)
And the dashboard home is displayed
When the user clicks "Logout"
Then the session is destroyed
And the browser is redirected to /login
And subsequent access to /dashboard requires login again
```

**Why this test?** Logout clears session; user is unprotected again.

---

## Capability 2: View Devices List

Dashboard displays all devices with quick action links.

### Scenario 2.1: List view shows all devices

```gherkin
Given a logged-in user
And 3 devices exist:
  | Name            | Type           | Status  |
  | Living Room Plug| smart_plug     | online  |
  | Bedroom Light   | led_controller | online  |
  | Kitchen Device  | smart_plug     | offline |

When GET /dashboard/devices
Then the response status is 200 OK
And a list/table is displayed with 3 rows
And each row shows: name, type, status
And each row has action links: [View], [Edit], [Delete], [+ Add Attribute]
And a button "[+ Add New Device]" is displayed at top
```

**Why this test?** List view is the dashboard home; users need to see all devices at a glance.

---

### Scenario 2.2: Empty state when no devices exist

```gherkin
Given a logged-in user
And no devices exist
When GET /dashboard/devices
Then the response is 200 OK
And a message "You have no devices yet" is displayed
And the "[+ Add New Device]" button is still visible
```

**Why this test?** UX feedback when state is empty; button still reachable for first device.

---

## Capability 3: Create New Device (Full CRUD)

User can add new devices from the dashboard.

### Scenario 3.1: Show new device form

```gherkin
Given a logged-in user
And GET /dashboard/devices/new
Then the response is 200 OK
And a form is displayed with fields:
  | Field              | Type      | Required |
  | Name               | text      | Yes      |
  | Type               | dropdown  | Yes      |
  | Brand              | text      | No       |
  | Model              | text      | No       |
  | Room               | text      | No       |
  | Status             | dropdown  | No       |
  | IP Address         | text      | No       |
  | MAC Address        | text      | No       |
  | Firmware Version   | text      | No       |
  | Purchase Date      | date      | No       |
  | Notes              | textarea  | No       |
And a "Create Device" submit button is visible
```

**Why this test?** Form shows all editable device fields; users can specify full metadata.

---

### Scenario 3.2: Create device via Turbo form submission

```gherkin
Given a logged-in user
And the new device form is open (no page reload expected)
When the user fills:
  | Name    | Kitchen Plug         |
  | Type    | smart_plug           |
  | Brand   | TP-Link              |
  | Room    | Kitchen              |
And submits the form
Then NO page reload occurs (Turbo handles it)
And the server creates the device via POST /v1/devices
And the new device appears in the devices list (Turbo updates DOM)
And a flash message "Device created successfully" is displayed
And the form closes (modal/drawer disappears)
```

**Why this test?** Turbo form submission: user fills form, submits via AJAX, server creates via API, Turbo replaces DOM. No page refresh needed.

---

### Scenario 3.3: Create device with validation error (required field missing)

```gherkin
Given a logged-in user
And the new device form is open
When the user submits without filling "Name"
Then NO page reload occurs
And the API returns 422 Unprocessable Entity
And an error message "Name can't be blank" is displayed in the form
And no device is created
```

**Why this test?** Validation errors handled via Turbo: form re-rendered with errors, user can fix and retry.

---

### Scenario 3.4: Create device with invalid type dropdown value (API validation)

```gherkin
Given a logged-in user
And the new device form is open
When the user attempts to submit with invalid Type value
Then the browser's form validation or API validation catches it
And the response is 422
And error message is displayed
```

**Why this test?** Type must be valid enum value (smart_plug, led_controller, etc.); API validates.

**Covered by**: `spec/requests/dashboard/devices_spec.rb` ("does not create a device with an invalid type..." / "does not update with an invalid type..."). Rails `enum` raises `ArgumentError` on an unrecognized value rather than producing a model validation error; `Dashboard::DevicesController` rescues it via `rescue_from ArgumentError, with: :handle_invalid_type` and re-renders `:new`/`:edit` with 422 and an "Invalid device type" message.

---

## Capability 4: View Device Details

User can see full device info + nested attributes in a table.

### Scenario 4.1: Show device detail with all attributes

```gherkin
Given a logged-in user
And a device exists with:
  | name              | Living Room Plug              |
  | type              | smart_plug                    |
  | brand             | TP-Link                       |
  | model             | Tapo P115                     |
  | room              | Living Room                   |
  | status            | online                        |
  | ip_address        | 192.168.1.100                 |
  | mac_address       | AA:BB:CC:DD:EE:FF             |
  | firmware_version  | 1.2.4                         |
And the device has 2 attributes:
  | Key      | Value |
  | power_w  | 12.5  |
  | voltage_v| 230   |

When GET /dashboard/devices/:id
Then the response is 200 OK
And device detail is displayed:
  | Field                | Value                   |
  | Name                 | Living Room Plug        |
  | Type                 | smart_plug              |
  | Brand                | TP-Link                 |
  | Model                | Tapo P115               |
  | Room                 | Living Room             |
  | Status               | online                  |
  | IP Address           | 192.168.1.100           |
  | MAC Address          | AA:BB:CC:DD:EE:FF       |
  | Firmware Version     | 1.2.4                   |

And a table of device attributes:
  | Key       | Value   | Updated     | Actions          |
  | power_w   | 12.5    | 2026-08-04  | [Edit] [Delete]  |
  | voltage_v | 230     | 2026-08-04  | [Edit] [Delete]  |

And action buttons:
  [Edit Device] [Delete Device]
  [+ Add New Attribute]
```

**Why this test?** Detail page shows device metadata + nested attributes. Users can see full device state and manage attributes.

---

### Scenario 4.2: Device detail with no attributes

```gherkin
Given a logged-in user
And a device exists with no attributes
When GET /dashboard/devices/:id
Then the attributes table shows "No attributes yet"
And "[+ Add New Attribute]" button is still visible
```

**Why this test?** Empty attributes UX feedback.

---

## Capability 5: Edit Device (Full CRUD)

User can modify any device field via in-place or modal form.

### Scenario 5.1: Show edit device form

```gherkin
Given a logged-in user viewing a device detail
When the user clicks "[Edit Device]"
Then a form appears (Turbo modal/drawer, no page reload)
And the form is pre-filled with current device values
And fields are editable:
  | Field              | Current Value           |
  | Name               | Living Room Plug        |
  | Type               | smart_plug              |
  | Brand              | TP-Link                 |
  | ...                | (all editable)          |
And a "Update Device" submit button is visible
```

**Why this test?** Edit form shows pre-filled values; user can modify.

---

### Scenario 5.2: Edit device via Turbo form

```gherkin
Given a logged-in user with edit form open
When the user changes:
  | Name   | Kitchen Smart Plug |
  | Status | offline            |
And submits the form
Then NO page reload occurs (Turbo)
And the server updates device via PATCH /v1/devices/:id
And the device detail is re-rendered with new values
And flash message "Device updated successfully" is displayed
```

**Why this test?** Turbo form submission updates device via API, re-renders detail view.

---

### Scenario 5.3: Edit device with validation error

```gherkin
Given a logged-in user with edit form open
When the user clears the "Name" field
And submits the form
Then NO page reload occurs
And 422 error is returned with "Name can't be blank"
And error is displayed in form
And device is NOT updated
```

**Why this test?** Validation errors handled inline via Turbo.

---

## Capability 6: Delete Device (Full CRUD)

User can delete a device and its attributes via Turbo confirmation.

### Scenario 6.1: Delete device from list

```gherkin
Given a logged-in user viewing devices list
When the user clicks [Delete] on a device row
Then a Turbo confirmation dialog appears:
  "Are you sure? This will delete the device and all its attributes."
```

**Why this test?** Confirmation prevents accidental deletion.

---

### Scenario 6.2: Confirm device deletion

```gherkin
Given a logged-in user with delete confirmation shown
When the user confirms
Then NO page reload occurs (Turbo)
And the server deletes device via DELETE /v1/devices/:id
And all device attributes are cascade-deleted
And the device row is removed from the list (Turbo updates DOM)
And flash message "Device deleted successfully" is displayed
```

**Why this test?** Turbo handles deletion + DOM update without page reload.

---

### Scenario 6.3: Cancel device deletion

```gherkin
Given a logged-in user with delete confirmation shown
When the user cancels
Then the confirmation closes
And NO delete request is sent
And the device remains in the list
```

**Why this test?** User can cancel destructive action.

---

## Capability 7: Create Device Attribute (Nested CRUD)

User can add key/value attributes to a device from the dashboard.

### Scenario 7.1: Show new attribute form

```gherkin
Given a logged-in user viewing device detail
When the user clicks "[+ Add New Attribute]"
Then an inline form appears (Turbo modal or table insert):
  | Field | Type |
  | Key   | text |
  | Value | text |
And a "Create Attribute" submit button is visible
```

**Why this test?** Form for adding attributes.

---

### Scenario 7.2: Create attribute via Turbo form

```gherkin
Given a logged-in user with attribute form open
When the user fills:
  | Key   | current_mA |
  | Value | 1.5        |
And submits the form
Then NO page reload occurs (Turbo)
And the server creates attribute via POST /v1/devices/:device_id/device_attributes
And a new row appears in the attributes table (Turbo inserts row)
And flash message "Attribute added successfully" is displayed
And the form clears or closes
```

**Why this test?** Turbo form creates attribute via API, updates attributes table.

---

### Scenario 7.3: Create attribute with missing key (validation)

```gherkin
Given a logged-in user with attribute form open
When the user submits without filling "Key"
Then NO page reload occurs
And API returns 422 "Key can't be blank"
And error message is displayed in form
And no attribute is created
```

**Covered by**: `spec/requests/dashboard/device_attributes_spec.rb` ("does not create an attribute with a blank key and re-renders the form with errors").

**Why this test?** Required field validation via Turbo.

---

### Scenario 7.4: Create attribute with duplicate key for same device

```gherkin
Given a logged-in user viewing device with existing attribute key: "power_w"
When the user attempts to create another attribute with key: "power_w"
Then NO page reload occurs
And API returns 422 "Key must be unique per device"
And error message is displayed
And no duplicate is created
```

**Why this test?** Device attribute keys are unique per device (API validates); dashboard shows error.

---

## Capability 8: Edit Device Attribute (Nested CRUD)

User can modify attribute values (key is immutable).

### Scenario 8.1: Show edit attribute form (inline)

```gherkin
Given a logged-in user viewing device detail
When the user clicks [Edit] on an attribute row:
  | Key       | power_w |
  | Value     | 12.5    |
Then an inline form appears (table cell becomes input):
  | Field | Type | Current Value |
  | Value | text | 12.5          |
  (Key field is NOT shown or is read-only)
And a "Update Attribute" submit button is visible
```

**Why this test?** Edit form shows value only (key immutable).

---

### Scenario 8.2: Update attribute value via Turbo

```gherkin
Given a logged-in user with attribute edit form open
When the user changes value from "12.5" to "15.3"
And submits the form
Then NO page reload occurs (Turbo)
And the server updates attribute via PATCH /v1/devices/:device_id/device_attributes/:id
And the table row is re-rendered with new value (Turbo updates row)
And flash message "Attribute updated successfully" is displayed
```

**Why this test?** Turbo updates single table row; partial re-render.

---

### Scenario 8.3: Update attribute with validation error

```gherkin
Given a logged-in user with attribute edit form open
When the user clears the "Value" field
And submits the form
Then NO page reload occurs
And API returns 422
And error message is displayed inline
And the row is NOT updated
```

**Why this test?** Validation errors shown inline.

---

## Capability 9: Delete Device Attribute (Nested CRUD)

User can remove attributes from a device.

### Scenario 9.1: Delete attribute from table

```gherkin
Given a logged-in user viewing device detail
When the user clicks [Delete] on an attribute row:
  | Key   | power_w |
  | Value | 12.5    |
Then a Turbo confirmation appears:
  "Are you sure? This will delete the attribute."
```

**Why this test?** Confirmation before delete.

---

### Scenario 9.2: Confirm attribute deletion

```gherkin
Given a logged-in user with attribute delete confirmation shown
When the user confirms
Then NO page reload occurs (Turbo)
And the server deletes attribute via DELETE /v1/devices/:device_id/device_attributes/:id
And the attribute row is removed from the table (Turbo removes row)
And flash message "Attribute deleted successfully" is displayed
```

**Why this test?** Turbo deletes single table row; no full page reload.

---

### Scenario 9.3: Cancel attribute deletion

```gherkin
Given a logged-in user with attribute delete confirmation shown
When the user cancels
Then the confirmation closes
And NO delete request is sent
And the attribute remains in the table
```

**Covered by**: `spec/system/dashboard/device_attributes_spec.rb` ("keeps the attribute and closes the modal on cancel"), mirroring the device-level cancel flow in `spec/system/dashboard/devices/destroy_spec.rb`.

**Why this test?** User can cancel.

---

## Capability 10: Turbo Interactivity (No Page Reloads)

All CRUD operations use Turbo to avoid full page refreshes.

### Scenario 10.1: Create device via Turbo (no page reload)

```gherkin
Given a logged-in user on devices list
When the user clicks "[+ Add New Device]"
And submits the form
Then the browser history does NOT change (no pushState)
And the page scroll position does NOT reset
And the devices list is updated with new device (Turbo Stream replaces list)
And NO page reload spinner visible
```

**Why this test?** Turbo provides seamless UX without page flashes.

---

### Scenario 10.2: Edit device via Turbo (list view updates)

```gherkin
Given a logged-in user on devices list
When the user clicks [Edit] on a device
And changes "Name", submits
Then the list row for that device is updated (Turbo replaces row)
And other rows are NOT affected
And no full page reload
```

**Why this test?** Turbo targets specific DOM elements for update.

---

### Scenario 10.3: Network error handling (Turbo graceful degradation)

```gherkin
Given a logged-in user with form open
When the user submits a form
And the server returns 500 or network error
Then the form is NOT cleared
And an error message is displayed to the user
And the user can retry
```

**Why this test?** Turbo doesn't lose form data on network errors.

---

## Capability 11: Error Handling & UX

### Scenario 11.1: Flash messages for all actions

```gherkin
When user completes any action:
  | Action                | Flash Message                    |
  | Create device         | "Device created successfully"    |
  | Update device         | "Device updated successfully"    |
  | Delete device         | "Device deleted successfully"    |
  | Create attribute      | "Attribute added successfully"   |
  | Update attribute      | "Attribute updated successfully" |
  | Delete attribute      | "Attribute deleted successfully" |

Then the flash message appears at top of page
And disappears after 3-5 seconds (auto-dismiss)
```

**Why this test?** User feedback on every action.

---

### Scenario 11.2: 404 handling (deleted device accessed)

```gherkin
Given a logged-in user
And a device was deleted
When the user tries to access GET /dashboard/devices/:id (old ID)
Then the browser is redirected to /dashboard/devices
And a flash message "Device not found" is displayed
```

**Why this test?** Graceful handling of stale URLs.

---

### Scenario 11.3: Access control (unauthorized access)

```gherkin
Given two users: Alice and Bob
When Alice logs in as alice@example.com
And attempts to access /dashboard (generic dashboard)
Then Alice's devices are displayed (works)

Note: Single-user app, so this is mostly a placeholder for future multi-user support.
```

**Why this test?** Dashboard respects session auth.

---

## Summary: Spec Scenarios

| Capability | Scenario Count | Coverage |
|------------|---|---|
| Auth & Home | 3 | Login, logout, protection |
| View Devices List | 2 | List view, empty state |
| Create Device | 4 | Form, valid submit, validation, invalid type |
| View Device Detail | 2 | Detail with attributes, empty attributes |
| Edit Device | 3 | Form, valid submit, validation |
| Delete Device | 3 | Confirmation, confirm, cancel |
| Create Attribute | 4 | Form, valid, missing key, duplicate key |
| Edit Attribute | 3 | Form, valid, validation |
| Delete Attribute | 3 | Confirmation, confirm, cancel |
| Turbo Interactivity | 3 | No page reload, targeted updates, error handling |
| Error Handling & UX | 3 | Flash messages, 404, access control |
| **Total** | **36 scenarios** | **Complete dashboard coverage** |

---

## Design Questions for Next Phase

1. **Modal vs. Drawer vs. Inline Forms**: Should create/edit forms appear as:
   - Modal dialog overlaying the page?
   - Slide-out drawer from right side?
   - Inline form rows in the table/list?
   
   **Recommendation**: Start with inline forms (simplest Turbo implementation), add modal later if needed.

2. **Form Reset After Submit**: After successful create/update, should form:
   - Auto-close (drawer/modal)?
   - Clear and stay open for another entry?
   - Show confirmation + auto-scroll to new item?
   
   **Recommendation**: Auto-close after 1s delay (gives user time to see confirmation).

3. **Attribute Edit UX**: Should editing an attribute value be:
   - Click [Edit] → inline form in table cell?
   - Click [Edit] → modal form with key + value?
   - Click value directly to edit (double-click)?
   
   **Recommendation**: Inline form (simpler, faster).

4. **Confirmation Dialogs**: Use:
   - Turbo built-in `data-turbo-confirm` (simple)?
   - Custom modal (polished)?
   - None (dangerous but fast)?
   
   **Recommendation**: Turbo `data-turbo-confirm` for MVP.

5. **Attribute Uniqueness Validation**: Key uniqueness is enforced by API (422 on duplicate). Should dashboard:
   - Show list of existing keys to user (prevents accidental duplicates)?
   - Let user try, show API error (simpler)?
   
   **Recommendation**: Let user try, show error (teaches error handling).

---

## How These Specs Drive Implementation

**RED phase**: All 36 scenarios FAIL (dashboard doesn't exist yet)

**GREEN phase**: Implement:
- SessionsController (login/logout)
- DashboardController (home page)
- Dashboard::DevicesController (list, create, show, edit, delete views)
- Dashboard::DeviceAttributesController (nested CRUD views)
- Turbo forms with error handling
- Flash messages
- Stimulus.js controllers (if needed for confirmations)

**Expected**: All 36 tests pass after implementation

---

## Questions for Clarification Before Design Phase

1. ✓ Scope confirmed (full CRUD: devices + attributes)
2. ✓ Auth strategy confirmed (sessions for dashboard)
3. ✓ Styling confirmed (Bootstrap CDN)
4. ❓ **Form UX preference**: Modal, drawer, or inline forms? (see Design Questions above)
5. ❓ **Key validation UX**: Show existing keys or let API reject duplicates?
6. ❓ **Auto-close after submit**: Should forms close after 1s, or stay open?

Answer these design questions and we're ready for DESIGN phase.
