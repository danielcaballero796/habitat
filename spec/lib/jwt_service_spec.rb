require "rails_helper"

RSpec.describe JwtService, type: :lib do
  let(:user_id) { 1 }
  let(:payload) { { user_id: user_id } }

  describe ".encode" do
    it "encodes a payload into a JWT token" do
      token = JwtService.encode(payload)
      expect(token).to be_a(String)
      expect(token).not_to be_empty
    end

    it "creates a token that can be decoded" do
      token = JwtService.encode(payload)
      decoded = JwtService.decode(token)
      expect(decoded["user_id"]).to eq user_id
    end

    it "includes exp claim with default 1 day expiry" do
      token = JwtService.encode(payload)
      decoded = JwtService.decode(token)
      expect(decoded).to have_key("exp")
      exp_time = Time.at(decoded["exp"])
      expect(exp_time).to be > Time.current
    end

    it "accepts custom expiry" do
      custom_exp = 2.days.from_now
      token = JwtService.encode(payload, exp: custom_exp)
      decoded = JwtService.decode(token)
      expect(Time.at(decoded["exp"])).to be_within(1).of(custom_exp)
    end

    it "uses HS256 algorithm" do
      token = JwtService.encode(payload)
      parts = token.split(".")
      expect(parts.length).to eq 3
    end
  end

  describe ".decode" do
    context "with valid token" do
      it "returns the decoded payload" do
        token = JwtService.encode(payload)
        decoded = JwtService.decode(token)
        expect(decoded["user_id"]).to eq user_id
      end

      it "preserves all payload fields" do
        payload_with_extra = { user_id: user_id, email: "admin@habitat.local", role: "admin" }
        token = JwtService.encode(payload_with_extra)
        decoded = JwtService.decode(token)
        expect(decoded["email"]).to eq "admin@habitat.local"
        expect(decoded["role"]).to eq "admin"
      end
    end

    context "with invalid token" do
      it "raises AuthenticationError for malformed token" do
        expect {
          JwtService.decode("invalid.token.here")
        }.to raise_error(JwtService::AuthenticationError)
      end

      it "raises AuthenticationError for tampered token" do
        token = JwtService.encode(payload)
        parts = token.split(".")
        tampered_token = parts[0] + "." + parts[1] + ".invalidsignature"
        expect {
          JwtService.decode(tampered_token)
        }.to raise_error(JwtService::AuthenticationError)
      end
    end

    context "with expired token" do
      it "raises AuthenticationError for expired token" do
        expired_token = JwtService.encode(payload, exp: 1.second.ago)
        expect {
          JwtService.decode(expired_token)
        }.to raise_error(JwtService::AuthenticationError)
      end
    end

    context "with empty token" do
      it "raises AuthenticationError for empty string" do
        expect {
          JwtService.decode("")
        }.to raise_error(JwtService::AuthenticationError)
      end
    end
  end

  describe ".secret" do
    around do |example|
      original_env_secret = ENV["JWT_SECRET"]
      example.run
    ensure
      if original_env_secret.nil?
        ENV.delete("JWT_SECRET")
      else
        ENV["JWT_SECRET"] = original_env_secret
      end
    end

    it "uses credentials.jwt_secret when present" do
      allow(Rails.application.credentials).to receive(:jwt_secret).and_return("from_credentials")
      ENV["JWT_SECRET"] = "from_env"
      expect(JwtService.secret).to eq "from_credentials"
    end

    it "falls back to ENV['JWT_SECRET'] when credentials.jwt_secret is nil" do
      allow(Rails.application.credentials).to receive(:jwt_secret).and_return(nil)
      ENV["JWT_SECRET"] = "from_env"
      expect(JwtService.secret).to eq "from_env"
    end

    it "raises when neither credentials.jwt_secret nor ENV['JWT_SECRET'] is set" do
      allow(Rails.application.credentials).to receive(:jwt_secret).and_return(nil)
      ENV.delete("JWT_SECRET")
      expect { JwtService.secret }.to raise_error(/Set JWT_SECRET/)
    end
  end
end
