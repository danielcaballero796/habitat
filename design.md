# Design: Device Model and EAV-lite Attributes

**Change ID**: `2026-08-03-device-foundation`  
**Status**: Design  
**Created**: 2026-08-03

---

## Overview

This design describes the Rails application structure, database schema, and model architecture for the Device and DeviceAttribute foundation. We'll be building a Rails 7.1 API-only application with PostgreSQL, running in Docker for reproducible development and deployment.

---

## Docker & Local Development Environment

**Why Docker?** 
- Reproducible environment: exact Ruby version, gems, PostgreSQL version on Windows, Mac, Linux
- No local Ruby/PostgreSQL installation pain (especially on Windows)
- Matches how Habitat will run on a home server later (containerized)
- Easy to reset: `docker compose down -v` destroys the database; `docker compose up` recreates it fresh
- Team/CI consistency: Docker ensures everyone runs the same environment

**Architecture:**
- `Dockerfile`: Builds a Ruby 3.3 image with Rails 7.1 and test dependencies
- `docker-compose.yml`: Two services:
  - `app`: Rails API (port 3000)
  - `db`: PostgreSQL (volume-backed for data persistence)

**Development Workflow:**
- `docker compose up` starts the services in the background
- `docker compose run --rm app <command>` runs one-off commands (rails generate, rspec, etc.)
- `docker compose exec app <command>` runs commands in the already-running app container
- `docker compose down -v` stops services and deletes volumes (clean slate)

---

## Architecture Decision: Why EAV-lite?

**The Problem:** Smart home devices have heterogeneous attributes:
- Tapo plugs have `power_w`, `voltage_v`, `current_ma`
- LED strips have `brightness`, `hue`, `saturation`
- Door sensors have `battery_level`, `open_closed_state`
- Relays have minimal attributes

**Three Approaches Considered:**

| Approach | Schema | Pros | Cons |
|----------|--------|------|------|
| **Single Table (all nullable columns)** | One `devices` table with 20+ nullable columns | Simple queries, no joins | Schema bloat, null waste, unclear field applicability, hard to extend |
| **STI (Single Table Inheritance)** | `devices` table with `type` column, subclass methods | Type-safe, object-oriented | Adds rows unnecessarily, query complexity, migration burden for new types |
| **EAV-lite (Our choice)** | `devices` table + `device_attributes` table (key-value pairs) | Flexible, extensible, clean schema, easy to add new device types | Slightly more complex queries, need to ensure key uniqueness per device |

**Why EAV-lite?** It's the sweet spot: clean schema, zero null waste, easy to add new device types without migrations, and Rails associations make it natural to work with. Future Home Assistant integrations can add new attribute keys without touching the schema.

---

## File Structure

After `rails new`, the project will have this structure (showing key files):

```
habitat/
├── .git/                          # Git repository (initialized in step zero)
├── .gitignore                     # Standard Rails gitignore
├── Dockerfile                     # Docker image definition (Ruby 3.3 + Rails 7.1)
├── docker-compose.yml             # Docker Compose services (app + postgres)
├── Gemfile                        # Rails dependencies (rspec-rails, factory_bot, etc.)
├── Gemfile.lock                   # Locked gem versions
├── config/
│   ├── database.yml               # PostgreSQL connection config (docker postgres:5432)
│   ├── puma.rb                    # API server config
│   └── initializers/
│       └── inflections.rb         # (optional) Rails naming customizations
├── app/
│   ├── models/
│   │   ├── device.rb              # Device model (core logic)
│   │   └── device_attribute.rb    # DeviceAttribute model
│   ├── controllers/               # (empty for now, future API endpoints)
│   └── serializers/               # (empty for now, future JSON responses)
├── db/
│   ├── migrate/
│   │   ├── 20260803000000_create_devices.rb
│   │   └── 20260803000001_create_device_attributes.rb
│   └── schema.rb                  # Auto-generated schema snapshot
├── spec/
│   ├── models/
│   │   ├── device_spec.rb         # Tests for Device model
│   │   └── device_attribute_spec.rb # Tests for DeviceAttribute model
│   ├── spec_helper.rb             # RSpec configuration
│   ├── rails_helper.rb            # Rails + RSpec integration
│   └── factories/
│       └── devices.rb             # Factory Bot fixtures (device, attributes)
└── README.md                      # Project documentation
```

**Why this structure?**
- `app/models/` contains all business logic (validations, associations)
- `db/migrate/` contains schema changes (reversible, version controlled)
- `spec/models/` contains unit tests (directly testable, no HTTP layer)
- `spec/factories/` provides reusable test data (DRY principle)

---

## Database Schema

### Migration 1: `create_devices`

```ruby
# db/migrate/[timestamp]_create_devices.rb
class CreateDevices < ActiveRecord::Migration[7.1]
  def change
    create_table :devices do |t|
      # Core identity
      t.string :name, null: false
      t.string :type, null: false  # enum stored as string

      # Device metadata
      t.string :brand
      t.string :model
      t.string :room
      t.string :status

      # Connection info
      t.string :ip_address
      t.string :mac_address

      # Firmware
      t.string :firmware_version

      # Lifecycle
      t.date :purchase_date
      t.text :notes

      # Rails timestamps
      t.timestamps
    end

    # Indexes for common queries
    add_index :devices, :type
    add_index :devices, :name
    add_index :devices, :room
  end
end
```

**Why these fields?**
- `name` and `type` are NOT NULL (required by spec)
- `type` is indexed because we'll filter by device type (e.g., "show all smart_plugs")
- All other fields are optional (nullable) — only devices that have them store them
- `timestamps` auto-manages `created_at` and `updated_at`

### Migration 2: `create_device_attributes`

```ruby
# db/migrate/[timestamp]_create_device_attributes.rb
class CreateDeviceAttributes < ActiveRecord::Migration[7.1]
  def change
    create_table :device_attributes do |t|
      # Foreign key to Device
      t.references :device, null: false, foreign_key: true

      # Key-value pair
      t.string :key, null: false
      t.text :value, null: false  # text allows longer values (sensor readings, JSON)

      t.timestamps
    end

    # Compound index: (device_id, key) for uniqueness
    add_index :device_attributes, [:device_id, :key], unique: true
  end
end
```

**Why this schema?**
- `device_id` is NOT NULL and has a foreign key constraint (data integrity)
- `key` and `value` are NOT NULL (spec requirement: must be present)
- Compound unique index on `(device_id, key)` ensures each key exists at most once per device (scoped uniqueness)
- Using `text` for `value` allows future JSON or sensor readings (more flexible than varchar)

**Final schema:**

```
devices (table)
├── id: integer (primary key)
├── name: string (NOT NULL)
├── type: string (NOT NULL, enum stored as string)
├── brand: string
├── model: string
├── room: string
├── status: string
├── ip_address: string
├── mac_address: string
├── firmware_version: string
├── purchase_date: date
├── notes: text
├── created_at: datetime (NOT NULL)
└── updated_at: datetime (NOT NULL)

device_attributes (table)
├── id: integer (primary key)
├── device_id: integer (NOT NULL, foreign key)
├── key: string (NOT NULL)
├── value: text (NOT NULL)
├── created_at: datetime (NOT NULL)
└── updated_at: datetime (NOT NULL)
└── unique index: (device_id, key)
```

---

## Model Architecture

### Device Model (`app/models/device.rb`)

```ruby
class Device < ApplicationRecord
  # Enum for type validation (closed list)
  enum :type, {
    smart_plug: "smart_plug",
    led_controller: "led_controller",
    binary_sensor: "binary_sensor",
    relay: "relay",
    power_strip: "power_strip",
    hub: "hub",
    zigbee_dongle: "zigbee_dongle"
  }

  # Associations
  has_many :device_attributes, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :type, presence: true
end
```

**Key decisions:**

1. **Enum with explicit mapping**: Rails enums store as strings in the database but expose as symbols in Ruby code. Explicit mapping (`:smart_plug => "smart_plug"`) makes the enum type-safe and queryable.

2. **`has_many :device_attributes, dependent: :destroy`**: When a Device is deleted, all its attributes are automatically deleted (prevents orphaned records). This satisfies Scenario 2.5.

3. **Minimal validations here**: We only validate presence of required fields. Type-specific validation (e.g., "power plugs must have a power_w attribute") belongs in a future Feature, not the foundation.

### DeviceAttribute Model (`app/models/device_attribute.rb`)

```ruby
class DeviceAttribute < ApplicationRecord
  # Associations
  belongs_to :device

  # Validations
  validates :key, presence: true
  validates :value, presence: true
  validates :key, uniqueness: { scope: :device_id, message: "must be unique per device" }
end
```

**Key decisions:**

1. **`belongs_to :device`**: Each attribute belongs to exactly one device (referential integrity).

2. **Presence validation for key and value**: Both are required (Scenarios 2.4 and 2.7).

3. **Scoped uniqueness validation**: `:key` must be unique within the scope of a single device. This allows different devices to have attributes with the same key names (e.g., two plugs can both have "power_w"), but no device can have duplicate keys. This satisfies Scenario 2.6 and matches the unique database index.

---

## Test Architecture

### Device Model Tests (`spec/models/device_spec.rb`)

Organized by capability:

```ruby
RSpec.describe Device, type: :model do
  # Capability 1: Device Creation (Scenarios 1.1–1.5)
  describe "creation" do
    # Test 1.1: create with required fields
    # Test 1.2: create with all fields
    # Test 1.3: name presence validation
    # Test 1.4: type presence validation
    # Test 1.5: invalid type enum error
  end

  # Capability 2: Device Attributes (Scenarios 2.1–2.7)
  describe "attributes association" do
    # Test 2.1: device with no attributes
    # Test 2.2: add single attribute
    # Test 2.3: add multiple attributes
    # Test 2.4: attribute key presence error
    # Test 2.7: attribute value presence error
    # Test 2.6: duplicate key error (via attribute creation)
    # Test 2.5: cascade delete on device destruction
  end

  # Capability 3: Validation (Scenarios 3.1–3.4)
  describe "timestamps" do
    # Test 3.3: created_at and updated_at auto-populated
    # Test 3.4: created_at unchanged on update, updated_at changes
  end

  # Capability 4: Associations (Scenarios 4.1, 4.3)
  describe "attribute access" do
    # Test 4.1: device.device_attributes returns collection
    # Test 4.3: device.device_attributes.find_by(key: "...") works
  end
end
```

### DeviceAttribute Model Tests (`spec/models/device_attribute_spec.rb`)

```ruby
RSpec.describe DeviceAttribute, type: :model do
  # Capability 2: Device Attributes (Scenarios 2.4, 2.6, 2.7)
  describe "validations" do
    # Test 2.4: key presence validation
    # Test 2.7: value presence validation
    # Test 2.6: key uniqueness per device
  end

  # Capability 4: Associations (Scenario 4.2)
  describe "associations" do
    # Test 4.2: attribute.device returns parent Device
  end

  # Capability 3: Type Storage (Scenario 3.2)
  describe "enum type storage" do
    # Test 3.1, 3.2: type stored as string, accessed as symbol
  end
end
```

---

## Why This Design?

| Decision | Rationale |
|----------|-----------|
| Rails 7.1 API-only | Lightweight, no view layer, perfect for mobile/external integrations |
| PostgreSQL | Robust, supports foreign keys and constraints natively, production-ready |
| EAV-lite pattern | Flexible schema, no bloat, easy to extend, matches smart home domain |
| Separate DeviceAttribute table | Cleanly separates core device data from type-specific attributes |
| Enum for type | Type-safe at the model layer, validates on assignment, prevents typos |
| Scoped uniqueness on key | Ensures current state (no history), fast queries, natural model semantics |
| Cascade delete | Prevents orphaned attributes, maintains data integrity automatically |
| Model-level tests only (no controller tests yet) | Validates foundation before building API endpoints |

---

## Future Directions (Out of Scope)

These decisions are intentionally deferred:

1. **API endpoints** (e.g., `GET /devices`, `POST /devices`) — come in next SDD cycle
2. **Attribute type coercion** (e.g., convert "12.5" to Float for power readings) — future Feature
3. **Attribute validation per device type** (e.g., "smart_plugs must have power_w") — future Feature
4. **Home Assistant sync** (read/write device state from HA) — future Integration
5. **Device state history** (track attribute value changes over time) — separate table if needed

---

## Implementation Approach (TDD Cycle)

Each test will follow the RED → GREEN → REFACTOR cycle:

1. **RED**: Write the test case (it fails because the code doesn't exist yet)
2. **GREEN**: Write the minimum Rails code to make it pass
3. **REFACTOR**: Clean up, ensure the code follows Rails conventions, optimize if needed

Example for Scenario 1.1:

```ruby
# Scenario 1.1 test (RED)
device = Device.create(name: "Living Room", type: :smart_plug)
expect(device).to be_persisted
expect(device.type).to eq :smart_plug

# Code to make it pass (GREEN)
# app/models/device.rb
class Device < ApplicationRecord
  enum :type, { smart_plug: "smart_plug" }
  validates :name, presence: true
  validates :type, presence: true
end

# Migration (GREEN)
# db/migrate/[timestamp]_create_devices.rb
create_table :devices do |t|
  t.string :name, null: false
  t.string :type, null: false
  t.timestamps
end
```

---

## Verification Checklist

After apply phase completes:

- [ ] Rails 7.1 API app initializes with `bundle install && rails db:create && rails db:migrate`
- [ ] Device model loads without errors: `rails c` → `Device` → no errors
- [ ] DeviceAttribute model loads: `rails c` → `DeviceAttribute` → no errors
- [ ] Migrations are reversible: `rails db:rollback STEP=2` succeeds
- [ ] All 19 RSpec tests pass: `rspec spec/models/`
- [ ] Schema matches expectations: `rails db:schema:dump` shows correct tables/indexes
- [ ] No warnings or deprecations in test output

