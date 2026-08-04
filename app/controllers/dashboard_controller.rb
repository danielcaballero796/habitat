# Dashboard home page: lists all devices for the logged-in user.
# Session-authenticated (see SessionsHelper#require_login), separate from
# the JWT-protected /v1/* JSON API.
class DashboardController < ApplicationController
  before_action :require_login

  def index
    @devices = Device.all
  end
end
