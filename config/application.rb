require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Habitat
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # The dashboard uses session-based login (separate from the JWT auth used
    # by the JSON API), so cookies/session support is added back manually on
    # top of the API-only middleware stack.
    config.session_store :cookie_store, key: "_habitat_session"
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options
    # api_only also skips requiring the flash middleware file entirely, so
    # ActionDispatch::Request never gets its `flash` method mixed in at all
    # (NoMethodError, not just an empty flash) — request specs/system specs
    # never hit this because something else in that boot path loads the file
    # first; a real `rails server` boot does not.
    config.middleware.use ActionDispatch::Flash

    # The dashboard's edit/update forms are real HTML <form> elements that
    # submit PATCH/PUT/DELETE via the standard Rails `_method` hidden field
    # (browsers can't natively send those verbs). Converting that back into
    # the real HTTP method normally happens in `Rack::MethodOverride`, but
    # API-only apps drop it along with the rest of the browser-oriented
    # middleware stack — so every dashboard edit/update/destroy form was
    # silently POSTing to a PATCH/DELETE-only route and getting a 404
    # (only ever caught by a real browser + Capybara system spec, since
    # request specs call `patch`/`delete` directly and never exercise the
    # method-override path at all). Added back for the same reason
    # Cookies/session were: the dashboard is a real HTML app layered on an
    # otherwise API-only Rails config.
    config.middleware.use Rack::MethodOverride
  end
end
