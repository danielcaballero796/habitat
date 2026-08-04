require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }

  describe "GET /login" do
    it "renders the login form" do
      get "/login"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("form")
      expect(response.body).to include("email")
      expect(response.body).to include("password")
    end
  end

  describe "POST /login" do
    context "with valid credentials" do
      it "sets the session with the user id" do
        post "/login", params: { email: "admin@habitat.local", password: "secure123" }
        expect(session[:user_id]).to eq user.id
      end

      it "redirects to the dashboard" do
        post "/login", params: { email: "admin@habitat.local", password: "secure123" }
        expect(response).to redirect_to("/dashboard")
      end
    end

    context "with invalid password" do
      it "does not set the session" do
        post "/login", params: { email: "admin@habitat.local", password: "wrongpassword" }
        expect(session[:user_id]).to be_nil
      end

      it "re-renders the login form with an error message" do
        post "/login", params: { email: "admin@habitat.local", password: "wrongpassword" }
        # :unprocessable_entity (422), not 200: Turbo Drive only renders a
        # form response's body in place when it's a redirect or a non-2xx
        # status. A bare 200 re-render is silently ignored client-side,
        # leaving the old page displayed — confirmed via a real browser
        # system spec (spec/system/dashboard/login_spec.rb). Every other
        # form-backed controller in this app already follows this
        # convention (see Dashboard::DevicesController#create/#update).
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Invalid email or password")
      end
    end

    context "with unknown email" do
      it "does not set the session and shows a generic error" do
        post "/login", params: { email: "nobody@habitat.local", password: "secure123" }
        expect(session[:user_id]).to be_nil
        expect(response.body).to include("Invalid email or password")
      end
    end
  end

  describe "DELETE /logout" do
    it "clears the session and redirects to /login" do
      post "/login", params: { email: "admin@habitat.local", password: "secure123" }
      expect(session[:user_id]).to eq user.id

      delete "/logout"
      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to("/login")
    end
  end

  describe "session auth does not interfere with JWT-protected API routes" do
    it "still requires a Bearer token on /v1/devices" do
      get "/v1/devices"
      expect(response).to have_http_status(:unauthorized)
    end

    it "does not require a Bearer token on /login" do
      get "/login"
      expect(response).to have_http_status(:ok)
    end
  end
end
