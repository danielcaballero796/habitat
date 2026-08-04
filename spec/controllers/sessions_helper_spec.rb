require "rails_helper"

RSpec.describe SessionsHelper, type: :controller do
  controller(ApplicationController) do
    before_action :require_login, only: :protected_action

    def public_action
      render json: { logged_in: logged_in? }
    end

    def protected_action
      render json: { user_id: current_user.id }
    end
  end

  before do
    routes.draw do
      get "public_action" => "anonymous#public_action"
      get "protected_action" => "anonymous#protected_action"
    end
  end

  let(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }

  describe "#current_user" do
    it "returns the User matching session[:user_id]" do
      session[:user_id] = user.id
      get :protected_action
      body = JSON.parse(response.body)
      expect(body["user_id"]).to eq user.id
    end
  end

  describe "#logged_in?" do
    it "is false without a session" do
      get :public_action
      expect(JSON.parse(response.body)["logged_in"]).to eq false
    end

    it "is true with a session" do
      session[:user_id] = user.id
      get :public_action
      expect(JSON.parse(response.body)["logged_in"]).to eq true
    end
  end

  describe "#require_login" do
    it "redirects to /login when not logged in" do
      get :protected_action
      expect(response).to redirect_to(login_path)
    end

    it "allows the request through when logged in" do
      session[:user_id] = user.id
      get :protected_action
      expect(response).to have_http_status(:ok)
    end
  end
end
