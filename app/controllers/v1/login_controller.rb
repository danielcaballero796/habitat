module V1
  class LoginController < ApplicationController
    # Login happens before a JWT exists, so it can't inherit from
    # V1::BaseController (which requires Authenticable auth). It previously
    # relied on ApplicationController's format-based CSRF exemption; now that
    # exemption is unconditional for the dashboard, so this needs its own
    # explicit opt-out — there's no session/CSRF token to send here either.
    skip_forgery_protection

    def login
      user = User.find_by(email: params[:email])

      if user&.authenticate(params[:password])
        token = JwtService.encode({ user_id: user.id })
        render json: { token: token }, status: :ok
      else
        render json: { errors: { authentication: ["Invalid email or password"] } }, status: :unauthorized
      end
    end
  end
end
