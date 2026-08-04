require "rails_helper"

RSpec.describe "Creating a device from the dashboard", type: :system do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }

  before do
    sign_in(user, password: "secure123")
    visit "/dashboard/devices"
  end

  it "opens the add-device modal without navigating away from the list" do
    click_link "+ Add New Device"

    expect(page).to have_current_path("/dashboard/devices")
    expect(page).to have_css("#device-modal.open")
    within "#device-modal" do
      expect(page).to have_field("device[name]")
    end
  end

  it "creates a device and shows it in the list with no page reload" do
    click_link "+ Add New Device"

    within "#device-modal" do
      fill_in "device[name]", with: "Kitchen Plug"
      select "smart_plug", from: "device[type]"
      fill_in "device[brand]", with: "TP-Link"
      fill_in "device[room]", with: "Kitchen"
      click_button "Create Device"
    end

    expect(page).to have_current_path("/dashboard/devices")
    expect(page).to have_content("Kitchen Plug")
    expect(page).not_to have_css("#device-modal.open")
    expect(page).to have_content("Device created successfully")
  end

  it "keeps the modal open and shows the validation error when required fields are missing" do
    click_link "+ Add New Device"

    within "#device-modal" do
      fill_in "device[name]", with: ""
      click_button "Create Device"
    end

    expect(page).to have_css("#device-modal.open")
    within "#device-modal" do
      expect(page).to have_content("Name can't be blank")
    end
    expect(Device.count).to eq(0)
  end
end
