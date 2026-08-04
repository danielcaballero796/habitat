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
      redirect_to "/dashboard", notice: "Logged in successfully"
    else
      flash.now[:alert] = "Invalid email or password"
      render :new
    end
  end

  def destroy
    # DELETE /logout
    session.delete(:user_id)
    redirect_to login_path, notice: "Logged out"
  end
end
