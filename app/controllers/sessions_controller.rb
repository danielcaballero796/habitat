# Session-based authentication for the dashboard. This is intentionally
# separate from the JWT auth used by the JSON API (see Authenticable /
# V1::BaseController): the dashboard is browser-driven and uses a signed,
# httpOnly session cookie instead of a bearer token.
class SessionsController < ApplicationController
  def new
    # GET /login
  end

  def create
    # POST /login
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to dashboard_path, notice: "Logged in successfully"
    else
      flash.now[:alert] = "Invalid email or password"
      # Turbo Drive only renders a form response's body in place when the
      # response is a redirect OR a non-2xx status; a bare 200 re-render
      # (the implicit default here) is silently ignored, leaving the old
      # page displayed. Every other form-backed controller in this app
      # already uses :unprocessable_entity for the same reason (see
      # Dashboard::DevicesController#create/#update).
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    # DELETE /logout
    session.delete(:user_id)
    redirect_to login_path, notice: "Logged out"
  end
end
