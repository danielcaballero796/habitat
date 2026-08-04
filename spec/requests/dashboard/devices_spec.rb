require "rails_helper"

RSpec.describe "Dashboard::Devices", type: :request do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }

  before { post "/login", params: { email: user.email, password: "secure123" } }

  describe "GET /dashboard/devices" do
    it "returns 200 OK" do
      get "/dashboard/devices"
      expect(response).to have_http_status(:ok)
    end

    it "lists existing devices" do
      device = Device.create!(name: "Living Room Plug", type: :smart_plug, status: "online")
      get "/dashboard/devices"
      expect(response.body).to include("Living Room Plug")
      expect(response.body).to include(%(id="device-#{device.id}"))
    end

    it "shows the empty state when there are no devices" do
      get "/dashboard/devices"
      expect(response.body).to include("You have no devices yet")
    end

    it "shows the add device button" do
      get "/dashboard/devices"
      expect(response.body).to include("+ Add New Device")
    end

    context "when not logged in" do
      before { delete "/logout" }

      it "redirects to /login" do
        get "/dashboard/devices"
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe "GET /dashboard/devices/new" do
    it "returns 200 OK and renders the device form" do
      get "/dashboard/devices/new"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="device-modal"')
      expect(response.body).to include("name=\"device[name]\"")
      expect(response.body).to include("name=\"device[type]\"")
      expect(response.body).to include("name=\"device[brand]\"")
      expect(response.body).to include("name=\"device[model]\"")
      expect(response.body).to include("name=\"device[room]\"")
      expect(response.body).to include("name=\"device[status]\"")
      expect(response.body).to include("name=\"device[ip_address]\"")
      expect(response.body).to include("name=\"device[mac_address]\"")
      expect(response.body).to include("name=\"device[firmware_version]\"")
      expect(response.body).to include("name=\"device[purchase_date]\"")
      expect(response.body).to include("name=\"device[notes]\"")
    end
  end

  describe "POST /dashboard/devices" do
    let(:valid_params) do
      { device: { name: "Kitchen Plug", type: "smart_plug", brand: "TP-Link", room: "Kitchen" } }
    end

    it "creates the device and returns a turbo stream response" do
      expect {
        post "/dashboard/devices", params: valid_params, as: :turbo_stream
      }.to change(Device, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="close_modal"')
      expect(response.body).to include('target="device-modal"')
      expect(response.body).to include("Kitchen Plug")
      expect(response.body).to include("Device created successfully")
    end

    it "does not create an invalid device and re-renders the form with errors" do
      expect {
        post "/dashboard/devices", params: { device: { name: "", type: "smart_plug" } }, as: :turbo_stream
      }.not_to change(Device, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("can&#39;t be blank").or include("can't be blank")
    end
  end

  describe "GET /dashboard/devices/:id" do
    it "shows the device details" do
      device = Device.create!(name: "Living Room Plug", type: :smart_plug, brand: "TP-Link", room: "Living Room")
      get "/dashboard/devices/#{device.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Living Room Plug")
      expect(response.body).to include("TP-Link")
      expect(response.body).to include("Living Room")
    end

    it "shows a placeholder for device attributes" do
      device = Device.create!(name: "Living Room Plug", type: :smart_plug)
      get "/dashboard/devices/#{device.id}"

      expect(response.body).to include("Device Attributes")
      expect(response.body).to include("No attributes yet")
    end
  end

  describe "GET /dashboard/devices/:id/edit" do
    it "returns 200 OK and pre-fills the form" do
      device = Device.create!(name: "Living Room Plug", type: :smart_plug)
      get "/dashboard/devices/#{device.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="Living Room Plug"')
    end
  end

  describe "PATCH /dashboard/devices/:id" do
    it "updates the device and returns a turbo stream response" do
      device = Device.create!(name: "Living Room Plug", type: :smart_plug, status: "online")

      patch "/dashboard/devices/#{device.id}", params: { device: { name: "Kitchen Smart Plug", status: "offline" } }, as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="close_modal"')
      expect(response.body).to include('target="device-modal"')
      expect(response.body).to include("Kitchen Smart Plug")
      expect(response.body).to include("Device updated successfully")
      expect(device.reload.name).to eq("Kitchen Smart Plug")
    end

    it "does not update with invalid params and re-renders the form with errors" do
      device = Device.create!(name: "Living Room Plug", type: :smart_plug)

      patch "/dashboard/devices/#{device.id}", params: { device: { name: "" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_entity)
      expect(device.reload.name).to eq("Living Room Plug")
    end
  end

  describe "DELETE /dashboard/devices/:id" do
    it "deletes the device and returns a turbo stream response" do
      device = Device.create!(name: "Living Room Plug", type: :smart_plug)

      expect {
        delete "/dashboard/devices/#{device.id}", as: :turbo_stream
      }.to change(Device, :count).by(-1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("action=\"remove\"")
      expect(response.body).to include("target=\"device-#{device.id}\"")
      expect(response.body).to include("Device deleted successfully")
    end
  end
end
