module V1
  class DeviceAttributesController < BaseController
    before_action :set_device

    def index
      attributes = @device.device_attributes
      render json: attributes, each_serializer: DeviceAttributeSerializer
    end

    def create
      attribute = @device.device_attributes.new(attribute_params)
      if attribute.save
        render json: attribute, serializer: DeviceAttributeSerializer, status: :created
      else
        render json: { errors: attribute.errors }, status: :unprocessable_entity
      end
    end

    def update
      attribute = @device.device_attributes.find(params[:id])
      if attribute.update(attribute_params)
        render json: attribute, serializer: DeviceAttributeSerializer
      else
        render json: { errors: attribute.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      attribute = @device.device_attributes.find(params[:id])
      attribute.destroy
      head :no_content
    end

    private

    def set_device
      @device = Device.find(params[:device_id])
    end

    def attribute_params
      params.require(:device_attribute).permit(:key, :value)
    end
  end
end
