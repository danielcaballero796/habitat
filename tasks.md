# Tasks: Device Foundation Implementation

**Change ID**: `2026-08-03-device-foundation`  
**Status**: Tasks  
**Created**: 2026-08-03

---

## Overview

19 test scenarios → 19 RSpec test cases → Rails models to make them pass.

**Execution Strategy**: RED → GREEN → VERIFY
1. **RED**: Write all test cases first (they fail because code doesn't exist)
2. **GREEN**: Implement models and validations (tests pass)
3. **VERIFY**: Run full suite, confirm all tests pass

---

## Phase 0: Setup (Step Zero)

### Task 0.1: Verify git initialization [2 min]

```bash
cd C:\Users\Daniel\Desktop\habitat
git status
# Expected: "On branch main"
# This confirms step zero is complete
```

**Why?** SDD requires version control before implementing. Code needs to be tracked so we can commit the change as a single unit.

---

### Task 0.1b: Create placeholder Gemfile [1 min]

**Why this task?** The Dockerfile runs `COPY Gemfile*` at build time, but `rails new` hasn't run yet. We need a placeholder Gemfile so `docker compose build` succeeds.

Create `Gemfile` in the project root with minimal content:

```ruby
source "https://rubygems.org"
gem "rails", "~> 7.1.0"
```

**How?** Create this file manually, or:

```bash
cd C:\Users\Daniel\Desktop\habitat
cat > Gemfile << 'EOF'
source "https://rubygems.org"
gem "rails", "~> 7.1.0"
EOF
```

**What happens next:** Task 0.2 runs `rails new . --force`, which overwrites this placeholder with the real Gemfile. Then `bundle install` installs from the real one. This is the standard Rails-in-Docker bootstrap pattern.

**Expected result**: A minimal `Gemfile` exists in the project root. Docker can now build successfully.

---

### Task 0.2: Build Docker image and generate Rails skeleton [8 min]

**Prerequisite files** (created by SDD phases + Task 0.1b):
- `Dockerfile` — Ruby 3.3 + Rails 7.1 + dependencies
- `docker-compose.yml` — app (Rails) + db (PostgreSQL) services
- `Gemfile` — placeholder Gemfile (created in Task 0.1b, overwritten by rails new)

**Steps:**

```bash
cd C:\Users\Daniel\Desktop\habitat

# 1. Build the Docker image (first time only, ~3-5 min including Ruby download)
# Uses the placeholder Gemfile created in Task 0.1b
docker compose build

# 2. Generate Rails API skeleton inside the container
# The --force flag overwrites the placeholder Gemfile with the real one
docker compose run --rm app rails new . --api --force --database=postgresql --skip-git --skip-bundle

# 3. Reinstall gem dependencies from the real Gemfile
# This installs against the actual Rails Gemfile, not the placeholder
docker compose run --rm app bundle install
```

**After rails new completes, edit `config/database.yml`:**

Change all occurrences of `localhost` to `db` (the PostgreSQL Docker service name):

```yaml
# config/database.yml
development:
  <<: *default
  database: habitat_development
  host: db        # ← Change from "localhost" to "db"
  username: habitat
  password: habitat_dev

test:
  <<: *default
  database: habitat_test
  host: db        # ← Change from "localhost" to "db"
  username: habitat
  password: habitat_dev
```

**Why Docker?**
- No local Ruby/PostgreSQL installation needed (Windows compatibility)
- Reproducible environment across machines
- Matches production (containerized deployment)
- Easy reset: `docker compose down -v` destroys database; `docker compose up` recreates fresh

**Why API mode?** Smart home APIs (no server-rendered views).

**Expected result**: 
- Docker image built and tested
- Rails skeleton generated (Gemfile, config/, app/, db/, spec/ directories)
- Gems installed in container
- `config/database.yml` updated to point to Docker PostgreSQL service

---

## Phase 1: Database Migrations (Schema)

### Task 1.1: Create devices table migration [5 min]

```bash
docker compose run --rm app rails generate migration CreateDevices name:string type:string brand:string model:string room:string status:string ip_address:string mac_address:string firmware_version:string purchase_date:date notes:text
```

Then edit `db/migrate/[timestamp]_create_devices.rb`:

```ruby
class CreateDevices < ActiveRecord::Migration[7.1]
  def change
    create_table :devices do |t|
      t.string :name, null: false
      t.string :type, null: false
      t.string :brand
      t.string :model
      t.string :room
      t.string :status
      t.string :ip_address
      t.string :mac_address
      t.string :firmware_version
      t.date :purchase_date
      t.text :notes

      t.timestamps
    end

    add_index :devices, :type
    add_index :devices, :name
    add_index :devices, :room
  end
end
```

**Why NOT NULL on name and type?** Specs 1.3 and 1.4 require these fields. Database enforces it. If code somehow bypasses Rails validation, the database rejects invalid data.

**Why indexes?** We'll query devices by type (e.g., "show all smart_plugs"), by name (search), by room (filter). Indexes speed up these queries.

**Expected result**: A migration file ready to run (not yet applied).

---

### Task 1.2: Create device_attributes table migration [5 min]

```bash
docker compose run --rm app rails generate migration CreateDeviceAttributes device:references key:string value:text
```

Then edit `db/migrate/[timestamp]_create_device_attributes.rb`:

```ruby
class CreateDeviceAttributes < ActiveRecord::Migration[7.1]
  def change
    create_table :device_attributes do |t|
      t.references :device, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value, null: false

      t.timestamps
    end

    add_index :device_attributes, [:device_id, :key], unique: true
  end
end
```

**Why foreign_key: true?** Rails adds a database-level constraint: you can't create a device_attribute without a valid device_id. Prevents orphaned records.

**Why unique index on (device_id, key)?** Spec 2.6: No device can have duplicate keys. This index enforces it at the database layer (redundant with Rails validation, but defense-in-depth).

**Why text for value?** Allows long readings (sensor data, JSON payloads). More flexible than varchar.

**Expected result**: A migration that creates the device_attributes table with proper constraints.

---

### Task 1.3: Start Docker services and run migrations [3 min]

```bash
# 1. Start the Docker services (app and db) in the background
docker compose up -d

# 2. Wait ~5 seconds for PostgreSQL to be ready (see docker-compose.yml healthcheck)
# 3. Run database creation and migrations
docker compose run --rm app rails db:create
docker compose run --rm app rails db:migrate
```

**Expected result**: 
- PostgreSQL database `habitat_development` created
- Both tables (devices, device_attributes) exist with proper indexes and constraints
- Docker services running in background (check with `docker compose ps`)

---

## Phase 2: Model Stubs

### Task 2.1: Create Device model stub [2 min]

```bash
docker compose run --rm app rails generate model Device --skip-migration
# (skip migration because we already created it manually)
```

This creates `app/models/device.rb`. Leave it minimal for now:

```ruby
class Device < ApplicationRecord
end
```

**Why stubs first?** Rails needs the model file to exist before it can load associations. We'll add validations and enums in the GREEN phase.

---

### Task 2.2: Create DeviceAttribute model stub [2 min]

```bash
docker compose run --rm app rails generate model DeviceAttribute --skip-migration
```

This creates `app/models/device_attribute.rb`:

```ruby
class DeviceAttribute < ApplicationRecord
end
```

**Expected result**: Both model files exist but are empty (will be populated in GREEN phase).

---

## Phase 3: Test Infrastructure

### Task 3.1: Add RSpec and FactoryBot to Gemfile [3 min]

Edit `Gemfile`:

```ruby
group :development, :test do
  gem "rspec-rails"
  gem "factory_bot_rails"
end
```

Then rebuild the Docker image and reinstall gems:

```bash
docker compose build app
docker compose run --rm app bundle install
```

**Why RSpec?** Standard testing framework in Rails. Readable, expressive, pairs well with FactoryBot.

**Why FactoryBot?** Creates test data cleanly (replaces fixtures). `build` (in memory) vs `create` (in database).

---

### Task 3.2: Generate RSpec install [2 min]

```bash
docker compose run --rm app rails generate rspec:install
```

This creates:
- `spec/spec_helper.rb`
- `spec/rails_helper.rb`
- `.rspec` (RSpec config)

No edits needed. RSpec is now configured.

---

### Task 3.3: Create factories [5 min]

Create `spec/factories/devices.rb`:

```ruby
FactoryBot.define do
  factory :device do
    name { "Test Device" }
    type { :smart_plug }
    brand { "TP-Link" }
    model { "Tapo P115" }
    room { "Kitchen" }
    status { "online" }
    ip_address { "192.168.1.100" }
    mac_address { "AA:BB:CC:DD:EE:FF" }
    firmware_version { "1.2.4" }
    purchase_date { Date.today }
    notes { "Test device" }
  end

  factory :device_attribute do
    device
    key { "power_w" }
    value { "12.5" }
  end
end
```

**Why factories?** Instead of manually creating Device.new(...) in every test, `build(:device)` does it. Easy to override individual attributes per test.

**Expected result**: `spec/factories/devices.rb` ready to use in tests.

---

## Phase 4: RED Phase (Write All Tests)

### Task 4.1: Write Device model tests [10 min]

Create `spec/models/device_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe Device, type: :model do
  # ===== Capability 1: Device Creation (Scenarios 1.1-1.5) =====

  describe "creation with required fields only" do
    it "creates a Device with name and type" do
      device = Device.create(name: "Living Room", type: :smart_plug)
      expect(device).to be_persisted
      expect(device.name).to eq "Living Room"
      expect(device.type).to eq :smart_plug
      expect(device.id).to be_present
      expect(device.created_at).to be_present
    end
  end

  describe "creation with all fields" do
    it "stores all fields correctly" do
      device = Device.create(
        name: "Tapo Plug 1",
        type: :smart_plug,
        brand: "TP-Link",
        model: "Tapo P115",
        room: "Kitchen",
        status: "online",
        ip_address: "192.168.1.100",
        mac_address: "AA:BB:CC:DD:EE:FF",
        firmware_version: "1.2.4",
        purchase_date: Date.parse("2024-01-15"),
        notes: "Energy monitoring enabled"
      )
      expect(device).to be_persisted
      expect(device.brand).to eq "TP-Link"
      expect(device.notes).to eq "Energy monitoring enabled"
    end
  end

  describe "name validation" do
    it "requires a name (Scenario 1.3)" do
      device = Device.new(type: :smart_plug)
      expect(device.save).to be false
      expect(device.errors[:name]).to include "can't be blank"
      expect(Device.all.count).to eq 0
    end
  end

  describe "type validation" do
    it "requires a type (Scenario 1.4)" do
      device = Device.new(name: "Living Room")
      expect(device.save).to be false
      expect(device.errors[:type]).to include "can't be blank"
    end

    it "rejects invalid type enum values (Scenario 1.5)" do
      device = Device.new(name: "Test", type: :invalid_type)
      expect(device.save).to be false
      expect(device.errors[:type]).not_to be_empty
    end
  end

  # ===== Capability 2: Device Attributes (Scenarios 2.1-2.7) =====

  describe "attributes association" do
    it "device with no attributes is valid (Scenario 2.1)" do
      device = Device.create!(name: "Hub", type: :hub)
      expect(device.device_attributes.count).to eq 0
    end

    it "can add a single attribute (Scenario 2.2)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      attr = device.device_attributes.create!(key: "power_w", value: "12.5")
      expect(device.device_attributes.count).to eq 1
      expect(device.device_attributes.first.key).to eq "power_w"
      expect(attr.device_id).to eq device.id
    end

    it "can add multiple attributes (Scenario 2.3)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      device.device_attributes.create!(key: "power_w", value: "12.5")
      device.device_attributes.create!(key: "voltage_v", value: "230")
      device.device_attributes.create!(key: "current_ma", value: "54.3")
      expect(device.device_attributes.count).to eq 3
      expect(device.device_attributes.find_by(key: "power_w").value).to eq "12.5"
    end

    it "cascades delete on device destruction (Scenario 2.5)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      device.device_attributes.create!(key: "power_w", value: "12.5")
      device.device_attributes.create!(key: "voltage_v", value: "230")
      device_id = device.id
      device.destroy
      expect(Device.find_by(id: device_id)).to be_nil
      expect(DeviceAttribute.where(device_id: device_id).count).to eq 0
    end

    it "finds attribute by key (Scenario 4.3)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      device.device_attributes.create!(key: "power_w", value: "12.5")
      device.device_attributes.create!(key: "voltage_v", value: "230")
      result = device.device_attributes.find_by(key: "power_w")
      expect(result).not_to be_nil
      expect(result.value).to eq "12.5"
    end
  end

  # ===== Capability 3: Validation & Timestamps (Scenarios 3.3-3.4) =====

  describe "timestamps" do
    it "auto-populates created_at and updated_at (Scenario 3.3)" do
      device = Device.create!(name: "Test", type: :smart_plug)
      expect(device.created_at).to be_present
      expect(device.updated_at).to be_present
      expect((device.updated_at - device.created_at).abs).to be < 1
    end

    it "updates updated_at on update but not created_at (Scenario 3.4)" do
      device = Device.create!(name: "Old Name", type: :smart_plug)
      original_created_at = device.created_at
      sleep 0.1
      device.update(name: "New Name")
      expect(device.created_at).to eq original_created_at
      expect(device.updated_at).to be > original_created_at
    end
  end

  # ===== Capability 4: Associations (Scenario 4.1) =====

  describe "device_attributes association" do
    it "returns a collection with expected methods (Scenario 4.1)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      device.device_attributes.create!(key: "power_w", value: "12.5")
      device.device_attributes.create!(key: "voltage_v", value: "230")
      
      attrs = device.device_attributes
      expect(attrs).to respond_to(:count)
      expect(attrs).to respond_to(:each)
      expect(attrs).to respond_to(:first)
      expect(attrs).to respond_to(:create!)
      expect(attrs.count).to eq 2
    end
  end
end
```

**Why write tests first?** RED phase. Tests define the contract. When they pass, you know the code works.

**Expected result**: 11 test cases covering Device creation, attributes, validation, timestamps, and associations. All should FAIL at this point (red).

---

### Task 4.2: Write DeviceAttribute model tests [8 min]

Create `spec/models/device_attribute_spec.rb`:

```ruby
require "rails_helper"

RSpec.describe DeviceAttribute, type: :model do
  # ===== Capability 2: Device Attributes Validation (Scenarios 2.4, 2.6, 2.7) =====

  describe "validations" do
    it "requires a key (Scenario 2.4)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      attr = device.device_attributes.build(value: "12.5")
      expect(attr.save).to be false
      expect(attr.errors[:key]).to include "can't be blank"
      expect(device.device_attributes.count).to eq 0
    end

    it "requires a value (Scenario 2.7)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      attr = device.device_attributes.build(key: "power_w", value: "")
      expect(attr.save).to be false
      expect(attr.errors[:value]).to include "can't be blank"
    end

    it "enforces uniqueness of key per device (Scenario 2.6)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      device.device_attributes.create!(key: "power_w", value: "12.5")
      attr2 = device.device_attributes.build(key: "power_w", value: "13.0")
      expect(attr2.save).to be false
      expect(attr2.errors[:key]).not_to be_empty
      expect(device.device_attributes.count).to eq 1
    end
  end

  # ===== Capability 4: Associations (Scenario 4.2) =====

  describe "device association" do
    it "belongs to a device and returns parent (Scenario 4.2)" do
      device = Device.create!(name: "Tapo Plug", type: :smart_plug)
      attr = device.device_attributes.create!(key: "power_w", value: "12.5")
      expect(attr.device).to eq device
      expect(attr.device.id).to eq device.id
    end
  end

  # ===== Capability 3: Enum Type Storage (Scenario 3.1-3.2) =====

  describe "type enum storage" do
    it "stores type as string in DB, symbol in Ruby (Scenario 3.2)" do
      device = Device.create!(name: "Test", type: :smart_plug)
      reloaded = Device.find(device.id)
      expect(reloaded.type).to eq :smart_plug
      expect(reloaded.read_attribute_before_type_cast(:type)).to eq "smart_plug"
    end
  end
end
```

**Expected result**: 4 test cases covering attribute validation, associations, and enum type storage. All should FAIL at this point (red).

---

## Phase 5: GREEN Phase (Implement Models)

### Task 5.1: Implement Device model validations and enum [5 min]

Edit `app/models/device.rb`:

```ruby
class Device < ApplicationRecord
  # Enum: closed list of device types
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

**Why enum with explicit mapping?** Rails enums are type-safe. Try to assign an invalid type and Rails raises an error before the save attempt.

**Why dependent: :destroy?** When a Device is deleted, all its attributes are deleted automatically (Scenario 2.5).

**Expected result**: Device model now enforces validations and manages the enum.

---

### Task 5.2: Implement DeviceAttribute model validations and associations [5 min]

Edit `app/models/device_attribute.rb`:

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

**Why scoped uniqueness?** Different devices can have the same key (e.g., two plugs both have "power_w"), but no single device can have duplicate keys.

**Expected result**: DeviceAttribute model now enforces all required validations.

---

## Phase 6: Verify

### Task 6.1: Run full test suite [2 min]

```bash
docker compose exec app bundle exec rspec spec/models/
```

**Note**: Use `docker compose exec` (not `run --rm`) because the app container should already be running from Task 1.3.

**Expected output**: All 15 tests pass (GREEN phase complete).

```
Device
  creation with required fields only
    ✓ creates a Device with name and type
  creation with all fields
    ✓ stores all fields correctly
  name validation
    ✓ requires a name (Scenario 1.3)
  type validation
    ✓ requires a type (Scenario 1.4)
    ✓ rejects invalid type enum values (Scenario 1.5)
  attributes association
    ✓ device with no attributes is valid (Scenario 2.1)
    ✓ can add a single attribute (Scenario 2.2)
    ✓ can add multiple attributes (Scenario 2.3)
    ✓ cascades delete on device destruction (Scenario 2.5)
    ✓ finds attribute by key (Scenario 4.3)
  timestamps
    ✓ auto-populates created_at and updated_at (Scenario 3.3)
    ✓ updates updated_at on update but not created_at (Scenario 3.4)
  device_attributes association
    ✓ returns a collection with expected methods (Scenario 4.1)

DeviceAttribute
  validations
    ✓ requires a key (Scenario 2.4)
    ✓ requires a value (Scenario 2.7)
    ✓ enforces uniqueness of key per device (Scenario 2.6)
  device association
    ✓ belongs to a device and returns parent (Scenario 4.2)
  type enum storage
    ✓ stores type as string in DB, symbol in Ruby (Scenario 3.2)

15 examples, 0 failures
```

**Why this verification?** GREEN phase done when all tests pass. If any test fails, return to implementation and debug.

---

## Task Summary

| Phase | Task | Duration | Key Objective |
|-------|------|----------|---------------|
| 0.1 | Verify git init | 2 min | Confirm version control |
| 0.1b | Create placeholder Gemfile | 1 min | Bootstrap Gemfile for Docker build (overwritten by rails new) |
| 0.2 | Build Docker & Rails new | 8 min | Build image, generate Rails skeleton, install real gems |
| 1.1 | devices migration (Docker) | 5 min | Create devices table via `docker compose run` |
| 1.2 | device_attributes migration (Docker) | 5 min | Create device_attributes table via `docker compose run` |
| 1.3 | Start Docker & run migrations | 3 min | `docker compose up -d`, then `db:create` and `db:migrate` |
| 2.1 | Device model stub (Docker) | 2 min | Create app/models/device.rb via `docker compose run` |
| 2.2 | DeviceAttribute stub (Docker) | 2 min | Create app/models/device_attribute.rb via `docker compose run` |
| 3.1 | Add RSpec gems (Docker) | 3 min | Update Gemfile, rebuild Docker, `bundle install` |
| 3.2 | RSpec install (Docker) | 2 min | Generate spec config via `docker compose run` |
| 3.3 | Create factories | 5 min | Build factory_bot fixtures (manual file edit) |
| 4.1 | Device tests (RED) | 10 min | Write 11 test cases (manual file edit) |
| 4.2 | DeviceAttribute tests (RED) | 8 min | Write 4 test cases (manual file edit) |
| 5.1 | Device model (GREEN) | 5 min | Add enum, associations, validations (manual file edit) |
| 5.2 | DeviceAttribute model (GREEN) | 5 min | Add associations, validations (manual file edit) |
| 6.1 | Run full test suite (Docker) | 2 min | Verify all 15 tests pass via `docker compose exec` |
| **TOTAL** | | **~66-76 minutes** | Device foundation complete (includes Docker build ~5-10 min first time) |

---

## Why This Task Breakdown?

**Parallel phases**: Tasks 0-3 (setup, migrations, infrastructure) are prerequisites. No parallelism needed—each builds on the previous.

**RED before GREEN**: Tasks 4.1-4.2 (write tests) happen before 5.1-5.2 (write code). This ensures tests drive implementation, not the reverse.

**Small checkpoints**: Each task is 2-10 minutes. Easier to track progress, spot errors, stay focused.

**Testing-first**: By the time you finish 5.2, all 15 tests should pass. This proves the implementation matches the spec.

---

## Next Phase: Apply

The Apply phase will execute these tasks in order, running the commands and writing the code. You'll see exactly how the specs become tests, and tests become a working Rails foundation.

Ready to apply?

