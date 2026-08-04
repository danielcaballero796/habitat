class ApplicationController < ActionController::Base
  include SessionsHelper

  # The dashboard (session auth, HTML forms) needs CSRF protection; JSON API
  # requests (JWT-authenticated, no session cookie) are exempt since they
  # can't carry a CSRF token and don't rely on cookie-based auth.
  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  helper_method :current_user, :logged_in?

  private

  def render_not_found
    render json: { errors: { base: ["Resource not found"] } }, status: :not_found
  end
end
