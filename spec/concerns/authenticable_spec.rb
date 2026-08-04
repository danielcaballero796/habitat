require "rails_helper"

RSpec.describe Authenticable, type: :concern do
  let(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }
  let(:token) { JwtService.encode(user_id: user.id) }

  describe "JWT verification" do
    context "with valid token in Authorization header" do
      it "sets @current_user" do
        get :index, headers: { "Authorization" => "Bearer #{token}" }
        expect(assigns(:current_user)).to eq user
      end

      it "allows request to proceed" do
        get :index, headers: { "Authorization" => "Bearer #{token}" }
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
        get :index, headers: { "Authorization" => "Bearer invalid.token.here" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns authentication error message" do
        get :index, headers: { "Authorization" => "Bearer invalid.token.here" }
        body = JSON.parse(response.body)
        expect(body["errors"]["authentication"]).to include("Invalid or expired token")
      end
    end

    context "with expired token" do
      it "returns 401 Unauthorized" do
        expired_token = JwtService.encode(user_id: user.id, exp: 1.second.ago)
        get :index, headers: { "Authorization" => "Bearer #{expired_token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with token for non-existent user" do
      it "returns 401 Unauthorized" do
        token = JwtService.encode(user_id: 99999)
        get :index, headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with malformed Authorization header" do
      it "returns 401 when Bearer not present" do
        get :index, headers: { "Authorization" => "Basic #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 when header is empty" do
        get :index, headers: { "Authorization" => "" }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "login endpoint exemption" do
    it "allows login without authentication" do
      post :login, params: { email: "admin@habitat.local", password: "secure123" }
      expect(response).to have_http_status(:ok)
    end
  end
end

# Configure test controller that includes Authenticable
module V1
  class TestController < BaseController
    def index
      render json: { message: "success" }, status: :ok
    end

    def login
      render json: { message: "login success" }, status: :ok
    end
  end
end

# Mount test controller only in test environment
if Rails.env.test?
  Rails.application.routes.draw do
    get "up" => "rails/health#show", as: :rails_health_check
    namespace :v1 do
      post :login, to: 'test#login'
      get :index, to: 'test#index'
      resources :devices do
        resources :device_attributes, only: [:index, :create, :update, :destroy]
      end
    end
  end
end
