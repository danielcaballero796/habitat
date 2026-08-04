require "rails_helper"

RSpec.describe V1::DevicesController, type: :controller do
  let(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }
  let(:token) { JwtService.encode({ user_id: user.id }) }
  let(:device) { Device.create!(name: "Smart TV", type: "smart_plug", brand: "LG", model: "OLED55", room: "living_room", status: "active", ip_address: "192.168.1.100") }
  let(:valid_params) do
    {
      name: "Smart Light",
      type: "led_controller",
      brand: "Philips",
      model: "Hue",
      room: "bedroom",
      status: "active",
      ip_address: "192.168.1.101"
    }
  end

  before do
    request.headers["Authorization"] = "Bearer #{token}"
  end

  describe "GET #index" do
    it "returns all devices" do
      device
      get :index
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.length).to eq 1
    end

    it "serializes devices with nested attributes" do
      device.device_attributes.create!(key: "brightness", value: "80")
      get :index
      body = JSON.parse(response.body)
      expect(body[0]).to have_key("device_attributes")
      expect(body[0]["device_attributes"].length).to eq 1
    end

    context "without authentication" do
      before { request.headers["Authorization"] = nil }

      it "returns 401 Unauthorized" do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET #show" do
    it "returns a single device" do
      get :show, params: { id: device.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq device.id
      expect(body["name"]).to eq device.name
    end

    it "returns 404 for non-existent device" do
      get :show, params: { id: 99999 }
      expect(response).to have_http_status(:not_found)
    end

    context "without authentication" do
      before { request.headers["Authorization"] = nil }

      it "returns 401 Unauthorized" do
        get :show, params: { id: device.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST #create" do
    it "creates a new device" do
      post :create, params: { device: valid_params }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq "Smart Light"
      expect(body["type"]).to eq "led_controller"
    end

    it "returns created device with serialized data" do
      post :create, params: { device: valid_params }
      body = JSON.parse(response.body)
      expect(body).to have_key("id")
      expect(body).to have_key("created_at")
      expect(body).to have_key("device_attributes")
    end

    it "returns 422 with validation errors" do
      post :create, params: { device: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body).to have_key("errors")
    end

    context "without authentication" do
      before { request.headers["Authorization"] = nil }

      it "returns 401 Unauthorized" do
        post :create, params: { device: valid_params }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH #update" do
    it "updates an existing device" do
      patch :update, params: { id: device.id, device: { name: "Updated TV" } }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq "Updated TV"
    end

    it "returns 404 for non-existent device" do
      patch :update, params: { id: 99999, device: { name: "New Name" } }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 with validation errors" do
      patch :update, params: { id: device.id, device: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "without authentication" do
      before { request.headers["Authorization"] = nil }

      it "returns 401 Unauthorized" do
        patch :update, params: { id: device.id, device: { name: "Updated" } }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE #destroy" do
    it "deletes a device" do
      device
      delete :destroy, params: { id: device.id }
      expect(response).to have_http_status(:no_content)
      expect(Device.exists?(device.id)).to be false
    end

    it "returns 404 for non-existent device" do
      delete :destroy, params: { id: 99999 }
      expect(response).to have_http_status(:not_found)
    end

    context "without authentication" do
      before { request.headers["Authorization"] = nil }

      it "returns 401 Unauthorized" do
        delete :destroy, params: { id: device.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
