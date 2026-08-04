require "rails_helper"

RSpec.describe V1::DeviceAttributesController, type: :controller do
  let(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:device) { Device.create!(name: "Smart TV", type: "entertainment", brand: "LG", model: "OLED55", room: "living_room", status: "active", ip_address: "192.168.1.100") }
  let(:attribute) { device.device_attributes.create!(key: "brightness", value: "80") }

  before do
    request.headers["Authorization"] = "Bearer #{token}"
  end

  describe "GET #index" do
    it "returns all attributes for a device" do
      device.device_attributes.create!(key: "brightness", value: "80")
      device.device_attributes.create!(key: "contrast", value: "50")
      get :index, params: { device_id: device.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to be_an(Array)
      expect(body.length).to eq 2
    end

    it "returns empty array when device has no attributes" do
      get :index, params: { device_id: device.id }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body).to eq([])
    end

    it "returns 404 for non-existent device" do
      get :index, params: { device_id: 99999 }
      expect(response).to have_http_status(:not_found)
    end

    context "without authentication" do
      before { request.headers.delete("Authorization") }

      it "returns 401 Unauthorized" do
        get :index, params: { device_id: device.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST #create" do
    it "creates a new attribute for a device" do
      post :create, params: { device_id: device.id, device_attribute: { key: "volume", value: "30" } }
      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["key"]).to eq "volume"
      expect(body["value"]).to eq "30"
    end

    it "associates attribute with correct device" do
      post :create, params: { device_id: device.id, device_attribute: { key: "mode", value: "cinema" } }
      body = JSON.parse(response.body)
      expect(device.device_attributes.find(body["id"]).device_id).to eq device.id
    end

    it "returns 422 with validation errors" do
      post :create, params: { device_id: device.id, device_attribute: { key: "", value: "80" } }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body).to have_key("errors")
    end

    it "returns 404 for non-existent device" do
      post :create, params: { device_id: 99999, device_attribute: { key: "brightness", value: "80" } }
      expect(response).to have_http_status(:not_found)
    end

    context "without authentication" do
      before { request.headers.delete("Authorization") }

      it "returns 401 Unauthorized" do
        post :create, params: { device_id: device.id, device_attribute: { key: "brightness", value: "80" } }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH #update" do
    it "updates an existing attribute" do
      patch :update, params: { device_id: device.id, id: attribute.id, device_attribute: { value: "100" } }
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["value"]).to eq "100"
    end

    it "only permits key and value in params" do
      patch :update, params: { device_id: device.id, id: attribute.id, device_attribute: { value: "90", device_id: 999 } }
      updated_attr = device.device_attributes.find(attribute.id)
      expect(updated_attr.device_id).to eq device.id
    end

    it "returns 404 for non-existent attribute" do
      patch :update, params: { device_id: device.id, id: 99999, device_attribute: { value: "50" } }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 422 with validation errors" do
      patch :update, params: { device_id: device.id, id: attribute.id, device_attribute: { key: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    context "without authentication" do
      before { request.headers.delete("Authorization") }

      it "returns 401 Unauthorized" do
        patch :update, params: { device_id: device.id, id: attribute.id, device_attribute: { value: "50" } }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE #destroy" do
    it "deletes an attribute" do
      attribute
      delete :destroy, params: { device_id: device.id, id: attribute.id }
      expect(response).to have_http_status(:no_content)
      expect(DeviceAttribute.exists?(attribute.id)).to be false
    end

    it "returns 404 for non-existent attribute" do
      delete :destroy, params: { device_id: device.id, id: 99999 }
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for non-existent device" do
      delete :destroy, params: { device_id: 99999, id: attribute.id }
      expect(response).to have_http_status(:not_found)
    end

    context "without authentication" do
      before { request.headers.delete("Authorization") }

      it "returns 401 Unauthorized" do
        delete :destroy, params: { device_id: device.id, id: attribute.id }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
