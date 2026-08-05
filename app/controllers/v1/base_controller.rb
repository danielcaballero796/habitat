module V1
  class BaseController < ApplicationController
    include Authenticable
    # JWT-authenticated, no session cookie — CSRF protection doesn't apply here
    # (unlike ApplicationController#protect_from_forgery, which the session-based
    # dashboard still needs). Anchored to "is this a V1 controller", not response
    # format, so a future non-JSON /v1/* endpoint doesn't silently regain CSRF
    # enforcement it has no way to satisfy.
    skip_forgery_protection

    # All V1 endpoints that inherit from BaseController require auth
  end
end
