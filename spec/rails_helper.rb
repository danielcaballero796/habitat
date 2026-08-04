require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'capybara/rspec'
require 'capybara/cuprite'
require 'database_cleaner/active_record'

ActiveRecord::Migration.maintain_test_schema!

Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

Capybara.javascript_driver = :cuprite
Capybara.default_max_wait_time = 5

# Headless Chrome via Cuprite (Ferrum/CDP). Chromium binary path is
# configurable so the same suite runs both inside the Docker image (which
# installs the `chromium` apt package) and on a host machine that has
# Chrome/Chromium installed at a different path.
#
# NOTE: `:cuprite` is a driver type Rails' own `ActionDispatch::SystemTesting::Driver`
# knows how to register (see actionpack's system_testing/driver.rb#register_cuprite).
# `driven_by :cuprite` therefore re-registers the `:cuprite` Capybara driver
# itself using ONLY the `options:` hash passed here — any options set via a
# separate `Capybara.register_driver(:cuprite) { ... }` block get silently
# discarded because Rails' registration overwrites it. All driver options
# (browser flags, binary path, timeouts) MUST be passed through `options:`
# below, not via a manual `Capybara.register_driver` call.
CUPRITE_OPTIONS = {
  window_size: [1280, 1600],
  # Running as root inside the app container (see docker-compose.yml
  # `user: root`) requires --no-sandbox; --disable-dev-shm-usage avoids
  # crashes from Docker's small default /dev/shm size.
  browser_options: {
    "no-sandbox" => nil,
    "disable-gpu" => nil,
    "disable-dev-shm-usage" => nil
  },
  process_timeout: 20,
  inspector: false,
  headless: true,
  browser_path: ENV["CHROME_BIN"] || ENV["CHROMIUM_BIN"]
}

RSpec.configure do |config|
  config.fixture_path = "#{::Rails.root}/spec/fixtures"
  # Cleanup is fully delegated to DatabaseCleaner below (transaction
  # strategy for non-system specs, truncation for system specs), so Rails'
  # own transactional fixtures wrapper is disabled to avoid double-wrapping.
  config.use_transactional_fixtures = false
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.before(:each, type: :system) do
    driven_by :cuprite, options: CUPRITE_OPTIONS
  end

  # System specs drive the app through a real Puma server thread (see
  # `needs_server?` on the Cuprite driver), which checks out its own DB
  # connection from the pool — separate from the one the example's
  # `use_transactional_fixtures` wraps in an open transaction. Rows
  # created/committed by the app thread are invisible to a transaction the
  # test thread never committed, and vice versa, so the normal
  # transactional rollback strategy silently fails to clean up between
  # examples (symptom: "Email has already been taken" on the 2nd example).
  # DatabaseCleaner truncation runs in real committed transactions both
  # threads can see, so it's used for :system specs only; every other spec
  # type keeps the fast transactional rollback.
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.strategy = :transaction
  end

  config.before(:each, type: :system) do
    DatabaseCleaner.strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.append_after(:each) do
    DatabaseCleaner.clean
  end
end
