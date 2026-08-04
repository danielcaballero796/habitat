require "rails_helper"

RSpec.describe V1::LoginController, type: :controller do
  describe "POST #login" do
    let(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }

    context "with valid credentials" do
      it "returns a JWT token" do
        post :login, params: { email: "admin@habitat.local", password: "secure123" }
        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body).to have_key("token")
        expect(body["token"]).not_to be_empty
      end

      it "returns a valid JWT token that can be decoded" do
        post :login, params: { email: "admin@habitat.local", password: "secure123" }
        body = JSON.parse(response.body)
        decoded = JwtService.decode(body["token"])
        expect(decoded["user_id"]).to eq user.id
      end
    end

    context "with invalid email" do
      it "returns 401 Unauthorized" do
        post :login, params: { email: "nonexistent@habitat.local", password: "secure123" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns generic error message (no email leak)" do
        post :login, params: { email: "nonexistent@habitat.local", password: "secure123" }
        body = JSON.parse(response.body)
        expect(body["errors"]["authentication"]).to include("Invalid email or password")
      end
    end

    context "with invalid password" do
      it "returns 401 Unauthorized" do
        post :login, params: { email: "admin@habitat.local", password: "wrongpassword" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns generic error message" do
        post :login, params: { email: "admin@habitat.local", password: "wrongpassword" }
        body = JSON.parse(response.body)
        expect(body["errors"]["authentication"]).to include("Invalid email or password")
      end
    end

    context "with missing parameters" do
      it "handles missing email gracefully" do
        post :login, params: { password: "secure123" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "handles missing password gracefully" do
        post :login, params: { email: "admin@habitat.local" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
