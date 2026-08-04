module Authenticable
  extend ActiveSupport::Concern

  included do
    before_action :verify_jwt, except: [:login]
  end

  private

  def verify_jwt
    token = extract_token_from_header
    begin
      @current_user = User.find(JwtService.decode(token)["user_id"])
    rescue JwtService::AuthenticationError, ActiveRecord::RecordNotFound
      render json: { errors: { authentication: ["Invalid or expired token"] } }, status: :unauthorized
    end
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    header&.split(" ")&.last || raise(JwtService::AuthenticationError, "Missing token")
  end
end
