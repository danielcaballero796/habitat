# Dashboard home page. Redirects to the devices list, which is the
# only fully wired-up dashboard view (add/edit/delete via modal + Turbo Streams).
# Session-authenticated (see SessionsHelper#require_login), separate from
# the JWT-protected /v1/* JSON API.
class DashboardController < ApplicationController
  before_action :require_login

  def index
    redirect_to dashboard_devices_path
  end
end
