class ApplicationController < ActionController::Base
  include SessionsHelper

  # The dashboard (session auth, HTML forms) needs CSRF protection. JWT-based
  # controllers (no session cookie) opt out explicitly via
  # `skip_forgery_protection` rather than via a response-format heuristic.
  protect_from_forgery with: :exception

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  helper_method :current_user, :logged_in?

  private

  def render_not_found
    render json: { errors: { base: ["Resource not found"] } }, status: :not_found
  end
end
