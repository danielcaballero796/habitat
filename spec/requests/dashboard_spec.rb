require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }

  describe "GET /dashboard" do
    context "when logged in" do
      before { post "/login", params: { email: user.email, password: "secure123" } }

      it "redirects to the devices list" do
        get "/dashboard"
        expect(response).to redirect_to(dashboard_devices_path)
      end
    end

    context "when not logged in" do
      it "redirects to /login" do
        get "/dashboard"
        expect(response).to redirect_to(login_path)
      end

      it "does not render dashboard content" do
        get "/dashboard"
        expect(response.body).not_to include("Your Devices")
      end
    end
  end
end
