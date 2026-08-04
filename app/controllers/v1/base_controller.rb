module V1
  class BaseController < ApplicationController
    include Authenticable
    # All V1 endpoints that inherit from BaseController require auth
  end
end
