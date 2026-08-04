module V1
  class DevicesController < BaseController
    def index
      devices = Device.all
      render json: devices, each_serializer: DeviceSerializer
    end

    def create
      device = Device.new(device_params)
      if device.save
        render json: device, serializer: DeviceSerializer, status: :created
      else
        render json: { errors: device.errors }, status: :unprocessable_entity
      end
    end

    def show
      device = Device.find(params[:id])
      render json: device, serializer: DeviceSerializer
    end

    def update
      device = Device.find(params[:id])
      if device.update(device_params)
        render json: device, serializer: DeviceSerializer
      else
        render json: { errors: device.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      device = Device.find(params[:id])
      device.destroy
      head :no_content
    end

    private

    def device_params
      params.require(:device).permit(:name, :type, :brand, :model, :room, :status, :ip_address, :mac_address, :firmware_version, :purchase_date, :notes)
    end
  end
end
