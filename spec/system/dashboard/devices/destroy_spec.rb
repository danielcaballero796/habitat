require "rails_helper"

RSpec.describe "Deleting a device from the dashboard", type: :system do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }
  let!(:device) { Device.create!(name: "Living Room Plug", type: :smart_plug, status: "online") }

  before do
    sign_in(user, password: "secure123")
    visit "/dashboard/devices"
  end

  it "shows a confirmation modal instead of deleting immediately" do
    click_link "Delete"

    expect(page).to have_css("#confirm-delete-modal.open")
    within "#confirm-delete-modal" do
      expect(page).to have_content("Living Room Plug")
      expect(page).to have_button("Confirm Delete")
      expect(page).to have_button("Cancel")
    end
    expect(Device.count).to eq(1)
  end

  it "removes the device and shows a flash message on confirm" do
    click_link "Delete"

    within "#confirm-delete-modal" do
      click_button "Confirm Delete"
    end

    expect(page).not_to have_css("#device-#{device.id}")
    expect(page).to have_content("Device deleted successfully")
    expect(Device.count).to eq(0)
  end

  it "keeps the device and closes the modal on cancel" do
    click_link "Delete"

    within "#confirm-delete-modal" do
      click_button "Cancel"
    end

    expect(page).not_to have_css("#confirm-delete-modal.open")
    expect(page).to have_css("#device-#{device.id}")
    expect(Device.count).to eq(1)
  end
end
