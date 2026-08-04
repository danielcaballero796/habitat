require "rails_helper"

RSpec.describe "Dashboard::DeviceAttributes", type: :request do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }
  let!(:device) { Device.create!(name: "Living Room Plug", type: :smart_plug, status: "online") }

  before { post "/login", params: { email: user.email, password: "secure123" } }

  describe "GET /dashboard/devices/:device_id/device_attributes/new" do
    it "returns 200 OK and renders the attribute form" do
      get "/dashboard/devices/#{device.id}/device_attributes/new"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('id="attribute-modal"')
      expect(response.body).to include("name=\"device_attribute[key]\"")
      expect(response.body).to include("name=\"device_attribute[value]\"")
    end
  end

  describe "POST /dashboard/devices/:device_id/device_attributes" do
    let(:valid_params) { { device_attribute: { key: "brightness", value: "80" } } }

    it "creates the attribute and returns a turbo stream response" do
      expect {
        post "/dashboard/devices/#{device.id}/device_attributes", params: valid_params, as: :turbo_stream
      }.to change(DeviceAttribute, :count).by(1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="close_modal"')
      expect(response.body).to include('target="attribute-modal"')
      expect(response.body).to include("brightness")
      expect(response.body).to include("Attribute created successfully")
    end

    it "does not create a duplicate key and re-renders the form with errors" do
      DeviceAttribute.create!(device: device, key: "brightness", value: "50")

      expect {
        post "/dashboard/devices/#{device.id}/device_attributes",
             params: { device_attribute: { key: "brightness", value: "80" } }, as: :turbo_stream
      }.not_to change(DeviceAttribute, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("must be unique per device")
    end
  end

  describe "GET /dashboard/devices/:device_id/device_attributes/:id/edit" do
    it "returns 200 OK and pre-fills the form" do
      attribute = DeviceAttribute.create!(device: device, key: "brightness", value: "50")
      get "/dashboard/devices/#{device.id}/device_attributes/#{attribute.id}/edit"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('value="brightness"')
      expect(response.body).to include('value="50"')
    end
  end

  describe "PATCH /dashboard/devices/:device_id/device_attributes/:id" do
    it "updates the attribute and returns a turbo stream response" do
      attribute = DeviceAttribute.create!(device: device, key: "brightness", value: "50")

      patch "/dashboard/devices/#{device.id}/device_attributes/#{attribute.id}",
            params: { device_attribute: { value: "90" } }, as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="close_modal"')
      expect(response.body).to include('target="attribute-modal"')
      expect(response.body).to include("90")
      expect(response.body).to include("Attribute updated successfully")
      expect(attribute.reload.value).to eq("90")
    end

    it "does not update with invalid params and re-renders the form with errors" do
      attribute = DeviceAttribute.create!(device: device, key: "brightness", value: "50")

      patch "/dashboard/devices/#{device.id}/device_attributes/#{attribute.id}",
            params: { device_attribute: { value: "" } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_entity)
      expect(attribute.reload.value).to eq("50")
    end
  end

  describe "DELETE /dashboard/devices/:device_id/device_attributes/:id" do
    it "deletes the attribute and returns a turbo stream response" do
      attribute = DeviceAttribute.create!(device: device, key: "brightness", value: "50")

      expect {
        delete "/dashboard/devices/#{device.id}/device_attributes/#{attribute.id}", as: :turbo_stream
      }.to change(DeviceAttribute, :count).by(-1)

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include("action=\"remove\"")
      expect(response.body).to include("target=\"attribute-#{attribute.id}\"")
      expect(response.body).to include("Attribute deleted successfully")
    end
  end
end
