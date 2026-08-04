# Dashboard CRUD for devices. Session-authenticated (inherits require_login
# from DashboardController), separate from the JWT-protected /v1/devices
# JSON API. Create/update/destroy respond with Turbo Streams so the devices
# list updates without a full page reload.
module Dashboard
  class DevicesController < DashboardController
    before_action :set_device, only: [:show, :edit, :update, :destroy]

    rescue_from ActiveRecord::RecordNotFound, with: :redirect_device_not_found
    rescue_from ArgumentError, with: :handle_invalid_type

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

    # Device#type is a Rails enum backed by a closed list. Assigning an
    # unrecognized value (e.g. tampered <select>, curl, disabled JS) raises
    # ArgumentError instead of producing a validation error, so we rescue it
    # here and turn it into the spec-required 422 + re-rendered form.
    def handle_invalid_type
      @device ||= Device.new(device_params.except(:type))
      @device.errors.add(:type, "Invalid device type")

      if action_name == "update"
        render :edit, status: :unprocessable_entity
      else
        render :new, status: :unprocessable_entity
      end
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
