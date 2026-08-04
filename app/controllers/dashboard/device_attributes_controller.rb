# Dashboard nested CRUD for device attributes (EAV key/value pairs on a
# Device). Session-authenticated (inherits require_login from
# DashboardController), separate from the JWT-protected
# /v1/devices/:device_id/device_attributes JSON API. Create/update/destroy
# respond with Turbo Streams so the attributes list updates without a full
# page reload.
module Dashboard
  class DeviceAttributesController < DashboardController
    before_action :set_device
    before_action :set_attribute, only: [:edit, :update, :destroy]

    rescue_from ActiveRecord::RecordNotFound, with: :redirect_not_found

    def new
      @attribute = @device.device_attributes.new
    end

    def create
      @attribute = @device.device_attributes.new(attribute_params)

      if @attribute.save
        render turbo_stream: [
          turbo_stream.action(:close_modal, "attribute-modal"),
          turbo_stream.remove("no-attributes-row"),
          turbo_stream.append("attributes-list", partial: "dashboard/device_attributes/attribute", locals: { attribute: @attribute }),
          turbo_stream.update("flash", partial: "shared/flash", locals: { message: "Attribute created successfully" })
        ]
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @attribute.update(attribute_params)
        render turbo_stream: [
          turbo_stream.action(:close_modal, "attribute-modal"),
          turbo_stream.replace("attribute-#{@attribute.id}", partial: "dashboard/device_attributes/attribute", locals: { attribute: @attribute }),
          turbo_stream.update("flash", partial: "shared/flash", locals: { message: "Attribute updated successfully" })
        ]
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @attribute.destroy

      render turbo_stream: [
        turbo_stream.action(:close_modal, "confirm-delete-attribute-modal"),
        turbo_stream.remove("attribute-#{@attribute.id}"),
        turbo_stream.update("flash", partial: "shared/flash", locals: { message: "Attribute deleted successfully" })
      ]
    end

    private

    def set_device
      @device = Device.find(params[:device_id])
    end

    def set_attribute
      @attribute = @device.device_attributes.find(params[:id])
    end

    def redirect_not_found
      if @device.nil?
        redirect_to dashboard_devices_path, notice: "Device not found"
      else
        redirect_to dashboard_device_path(@device), notice: "Attribute not found"
      end
    end

    def attribute_params
      params.require(:device_attribute).permit(:key, :value)
    end
  end
end
