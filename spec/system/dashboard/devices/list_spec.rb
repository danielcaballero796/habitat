require "rails_helper"

RSpec.describe "Dashboard devices list", type: :system do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }

  before { sign_in(user, password: "secure123") }

  it "shows all devices with their name, type, and status" do
    Device.create!(name: "Living Room Plug", type: :smart_plug, status: "online")
    Device.create!(name: "Bedroom Light", type: :led_controller, status: "offline")

    visit "/dashboard/devices"

    expect(page).to have_content("Living Room Plug")
    expect(page).to have_content("smart_plug")
    expect(page).to have_content("Bedroom Light")
    expect(page).to have_content("led_controller")
  end

  it "shows the empty state when there are no devices" do
    visit "/dashboard/devices"

    expect(page).to have_content("You have no devices yet")
  end

  it "shows View, Edit, and Delete links for each device" do
    device = Device.create!(name: "Living Room Plug", type: :smart_plug, status: "online")

    visit "/dashboard/devices"

    within "#device-#{device.id}" do
      expect(page).to have_link("View")
      expect(page).to have_link("Edit")
      expect(page).to have_link("Delete")
    end
  end

  it "shows the + Add New Device button" do
    visit "/dashboard/devices"

    expect(page).to have_link("+ Add New Device")
  end
end
