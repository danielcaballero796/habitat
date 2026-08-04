require "rails_helper"

RSpec.describe Authenticable, type: :controller do
  controller(ApplicationController) do
    include Authenticable

    def index
      render json: { message: "success", current_user_id: @current_user.id }, status: :ok
    end
  end

  before do
    routes.draw { get "index" => "anonymous#index" }
  end

  let(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }
  let(:token) { JwtService.encode({ user_id: user.id }) }

  describe "JWT verification" do
    context "with valid token in Authorization header" do
      it "sets @current_user" do
        request.headers["Authorization"] = "Bearer #{token}"
        get :index
        body = JSON.parse(response.body)
        expect(body["current_user_id"]).to eq user.id
      end

      it "allows request to proceed" do
        request.headers["Authorization"] = "Bearer #{token}"
        get :index
        expect(response).to have_http_status(:ok)
      end
    end

    context "with missing Authorization header" do
      it "returns 401 Unauthorized" do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns authentication error message" do
        get :index
        body = JSON.parse(response.body)
        expect(body["errors"]["authentication"]).to include("Invalid or expired token")
      end
    end

    context "with invalid token" do
      it "returns 401 Unauthorized" do
        request.headers["Authorization"] = "Bearer invalid.token.here"
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns authentication error message" do
        request.headers["Authorization"] = "Bearer invalid.token.here"
        get :index
        body = JSON.parse(response.body)
        expect(body["errors"]["authentication"]).to include("Invalid or expired token")
      end
    end

    context "with expired token" do
      it "returns 401 Unauthorized" do
        expired_token = JwtService.encode({ user_id: user.id }, exp: 1.second.ago)
        request.headers["Authorization"] = "Bearer #{expired_token}"
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with token for non-existent user" do
      it "returns 401 Unauthorized" do
        token = JwtService.encode({ user_id: 99999 })
        request.headers["Authorization"] = "Bearer #{token}"
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with malformed Authorization header" do
      it "returns 401 when Bearer not present" do
        request.headers["Authorization"] = "Basic #{token}"
        get :index
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when header is empty" do
        request.headers["Authorization"] = ""
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
