class JwtService
  class AuthenticationError < StandardError; end

  def self.encode(payload, exp: 1.day.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, secret, "HS256")
  end

  def self.decode(token)
    JWT.decode(token, secret, true, algorithm: "HS256").first
  rescue JWT::DecodeError, JWT::ExpiredSignature => e
    raise AuthenticationError, e.message
  end

  private

  def self.secret
    Rails.application.credentials.jwt_secret || ENV.fetch("JWT_SECRET") do
      raise "Set JWT_SECRET (or credentials.jwt_secret) — refusing to sign JWTs with " \
            "secret_key_base, which is also used for session cookies and CSRF tokens."
    end
  end
end
