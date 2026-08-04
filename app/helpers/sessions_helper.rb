module SessionsHelper
  # Returns the currently logged-in User based on the session cookie,
  # or nil if no one is logged in. Memoized per request.
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  # True when a User is logged in via the session.
  def logged_in?
    !!current_user
  end

  # before_action filter: redirects to the dashboard login page when no
  # user is logged in. Intended for dashboard controllers only (not the
  # JWT-protected /v1/* API controllers).
  def require_login
    redirect_to login_path, alert: "Please log in to continue" unless logged_in?
  end
end
