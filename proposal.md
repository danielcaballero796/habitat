# Proposal: Initialize Rails API with Device Model and EAV-lite Attributes

**Change ID**: `2026-08-03-device-foundation`  
**Status**: Proposal  
**Created**: 2026-08-03

## Summary

Initialize a Rails 7.1 API application with a foundational Device model and associated DeviceAttribute model to support the smart home device registry. This change establishes the database schema and Rails structure that will serve as the foundation for future features (integrations, device control, monitoring, alerts).

## Why This Change?

**Problem**: The Habitat project needs to represent diverse smart home devices (energy-monitoring plugs, LED controllers, binary sensors, power strips, relays) where each device type has different attributes. A naive approach (one Device table with nullable columns for every possible attribute) leads to schema bloat, null values, and difficulty extending to new device types.

**Solution**: Implement a Device + DeviceAttribute association using an EAV-lite (Entity-Attribute-Value) pattern. Core device properties (name, type, brand, model, room, status, IP address, MAC address, firmware version, purchase date, notes) remain on Device. Type-specific attributes (energy readings, LED colors, battery levels, outlet states) are stored as key-value pairs in DeviceAttribute, indexed by device_id.

**Why now?** This is the first implementation task. It establishes the Rails project, database schema, and Rails patterns (models, migrations, validations, associations) that all future work depends on.

## Scope

**In scope:**
- Initialize Rails 7.1 API app with PostgreSQL
- Create Device model with core fields and validations
- Create DeviceAttribute model with device association
- Create database migrations (create_devices, create_device_attributes)
- Create model tests demonstrating Device creation, attribute access, and validation
- Git repository initialization and initial commit

**Out of scope:**
- API endpoints (GET /devices, POST /devices)
- Integration with Home Assistant or real devices
- Authentication or authorization
- Attributes UI, device firmware updates, or real-time monitoring

## Capabilities (for Spec phase)

The following capabilities will be specified in the Spec phase:

1. **Device Creation**
   - A Device can be created with a name and type
   - A Device requires a name (validates presence)
   - A Device requires a type (validates presence)
   - A Device type must be from an enum of known types (e.g., `:smart_plug`, `:led_controller`, `:binary_sensor`, `:relay`, `:power_strip`)

2. **Device Attributes**
   - A Device can have zero or more attributes
   - An attribute is a key-value pair (key: string, value: string)
   - Attributes are accessed via `device.attributes` (Rails association)
   - Attributes can be added, updated, or deleted through the Device object

3. **Device Validation**
   - A Device with valid core fields and attributes can be saved
   - A Device missing required fields cannot be saved
   - Validation errors provide clear messages

## Approach

**Database schema:**
- `devices` table: id, name, type, brand, model, room, status, ip_address, mac_address, firmware_version, purchase_date, notes, created_at, updated_at
- `device_attributes` table: id, device_id, key, value, created_at, updated_at

**Rails code:**
- `app/models/device.rb`: Device model with validations and `has_many :device_attributes, dependent: :destroy` association
- `app/models/device_attribute.rb`: DeviceAttribute model with `belongs_to :device` and indexed key-value storage
- `db/migrate/*_create_devices.rb`: Migration to create devices table
- `db/migrate/*_create_device_attributes.rb`: Migration to create device_attributes table
- `spec/models/device_spec.rb`: Model tests for Device (creation, validation, attributes)
- `spec/models/device_attribute_spec.rb`: Model tests for DeviceAttribute (association, validation)

**Rationale for this approach:**
- EAV-lite is flexible and extensible (new device types don't require schema changes)
- Rails models and associations make the pattern natural to work with
- Migrations are straightforward and reversible
- Model tests (not feature tests) validate the foundation before API endpoints are added

## Rollback Plan

If this change causes issues:
1. All code is isolated in models and migrations—no API endpoints to break
2. Rollback: `git reset --hard HEAD~1` (or revert the commit)
3. Run `rails db:rollback STEP=2` to undo migrations

## Success Criteria

- [ ] Rails 7.1 API app initializes without errors
- [ ] PostgreSQL database connects and migrations run successfully
- [ ] Device model validates presence of name and type
- [ ] Device model supports has_many association with DeviceAttribute
- [ ] DeviceAttribute model stores key-value pairs and belongs_to Device
- [ ] Model tests pass (4+ test cases covering creation, validation, attributes)
- [ ] Code follows Rails conventions (model naming, association syntax, test structure)
- [ ] Initial commit includes all code and passes `rails db:test:prepare && rspec spec/models/`

## Timeline

Single session: ~45–60 minutes
- Propose: 5 min (this document)
- Spec: 10 min (scenarios for Device and Attribute behavior)
- Design: 5 min (Rails file structure and migration structure)
- Tasks: 5 min (implementation steps)
- Apply: 20 min (generate Rails app, write models, migrations, tests)
- Verify: 5 min (run tests, confirm specs pass)
- Archive: 5 min (commit and clean up)

---

## Questions for Review

Before we proceed to the Spec phase, please confirm:

1. **Device type enum**: Should we hard-code device types (`:smart_plug`, `:led_controller`, `:binary_sensor`, `:relay`, `:power_strip`), or keep it open-ended (any string)?
2. **Attribute validation**: Should DeviceAttribute validate that the key is not empty, or allow any key?
3. **Core fields**: Are the fields (name, type, brand, model, room, status, ip_address, mac_address, firmware_version, purchase_date, notes) complete, or would you add/remove any?

