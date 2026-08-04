# Dashboard CRUD for devices. Session-authenticated (inherits require_login
# from DashboardController), separate from the JWT-protected /v1/devices
# JSON API. Create/update/destroy respond with Turbo Streams so the devices
# list updates without a full page reload.
module Dashboard
  class DevicesController < DashboardController
    before_action :set_device, only: [:show, :edit, :update, :destroy]

    rescue_from ActiveRecord::RecordNotFound, with: :redirect_device_not_found

    def index
      @devices = Device.all
    end

    def new
      @device = Device.new
    end

    def create
      @device = Device.new(device_params)

      if @device.save
        render turbo_stream: [
          turbo_stream.action(:close_modal, "device-modal"),
          turbo_stream.remove("no-devices-row"),
          turbo_stream.prepend("devices-list", partial: "device", locals: { device: @device }),
          turbo_stream.update("flash", partial: "shared/flash", locals: { message: "Device created successfully" })
        ]
      else
        render :new, status: :unprocessable_entity
      end
    end

    def show; end

    def edit; end

    def update
      if @device.update(device_params)
        render turbo_stream: [
          turbo_stream.action(:close_modal, "device-modal"),
          turbo_stream.replace("device-#{@device.id}", partial: "device", locals: { device: @device }),
          turbo_stream.update("flash", partial: "shared/flash", locals: { message: "Device updated successfully" })
        ]
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @device.destroy

      render turbo_stream: [
        turbo_stream.action(:close_modal, "confirm-delete-modal"),
        turbo_stream.remove("device-#{@device.id}"),
        turbo_stream.update("flash", partial: "shared/flash", locals: { message: "Device deleted successfully" })
      ]
    end

    private

    def set_device
      @device = Device.find(params[:id])
    end

    def redirect_device_not_found
      redirect_to dashboard_devices_path, notice: "Device not found"
    end

    def device_params
      params.require(:device).permit(
        :name, :type, :brand, :model, :room, :status,
        :ip_address, :mac_address, :firmware_version,
        :purchase_date, :notes
      )
    end
  end
end
