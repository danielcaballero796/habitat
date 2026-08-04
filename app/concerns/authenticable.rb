module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :verify_jwt
  end

  private

  def verify_jwt
    token = extract_token_from_header
    @current_user = User.find(JwtService.decode(token)["user_id"])
  rescue JwtService::AuthenticationError, ActiveRecord::RecordNotFound
    render json: { errors: { authentication: ["Invalid or expired token"] } }, status: :unauthorized
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    scheme, token = header.to_s.split(" ", 2)
    raise(JwtService::AuthenticationError, "Missing token") unless scheme == "Bearer" && token.present?

    token
  end
end
