require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }

  describe "GET /dashboard" do
    context "when logged in" do
      before { post "/login", params: { email: user.email, password: "secure123" } }

      it "returns 200 OK" do
        get "/dashboard"
        expect(response).to have_http_status(:ok)
      end

      it "shows the devices heading" do
        get "/dashboard"
        expect(response.body).to include("Your Devices")
      end

      it "shows a welcome message with the user's email" do
        get "/dashboard"
        expect(response.body).to include("Welcome, #{user.email}")
      end

      it "shows the add device button" do
        get "/dashboard"
        expect(response.body).to include("+ Add New Device")
      end

      it "lists existing devices" do
        Device.create!(name: "Living Room Plug", type: :smart_plug)
        get "/dashboard"
        expect(response.body).to include("Living Room Plug")
      end

      it "renders the device modal shell wired to the Stimulus modal controller" do
        get "/dashboard"
        expect(response.body).to include('id="device-modal"')
        expect(response.body).to include('data-controller="modal"')
        expect(response.body).to include('data-action="click->modal#closeOnBackdrop"')
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
