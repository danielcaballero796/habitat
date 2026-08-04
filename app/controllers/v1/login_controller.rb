module V1
  class LoginController < ApplicationController
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
