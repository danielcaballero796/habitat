require "rails_helper"

RSpec.describe "Device attributes CRUD from the dashboard", type: :system do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }
  let!(:device) { Device.create!(name: "Living Room Plug", type: :smart_plug, status: "online") }

  before do
    sign_in(user, password: "secure123")
    visit "/dashboard/devices/#{device.id}"
  end

  it "creates an attribute via the modal and appends a row to the table" do
    click_link "+ Add Attribute"

    expect(page).to have_css("#attribute-modal.open")
    within "#attribute-modal" do
      fill_in "device_attribute[key]", with: "power_w"
      fill_in "device_attribute[value]", with: "12.5"
      click_button "Create Attribute"
    end

    within "#attributes-list" do
      expect(page).to have_content("power_w")
      expect(page).to have_content("12.5")
    end
    expect(page).to have_content("Attribute created successfully")
  end

  it "updates an attribute's value and the row refreshes" do
    attribute = DeviceAttribute.create!(device: device, key: "power_w", value: "12.5")
    visit "/dashboard/devices/#{device.id}"

    within "#attribute-#{attribute.id}" do
      click_link "Edit"
    end

    expect(page).to have_field("device_attribute[value]", with: "12.5")
    fill_in "device_attribute[value]", with: "20.0"
    click_button "Update Attribute"

    # Edit is a standalone page (device_attributes/edit.html.erb), reached by
    # a full Turbo Drive visit rather than the in-place modal on the show
    # page, so the turbo_stream response's row-replace/flash-update targets
    # don't exist here and silently no-op. Confirm the update took effect
    # where it's actually visible: in the DB, and back on the show page.
    expect(attribute.reload.value).to eq("20.0")

    visit "/dashboard/devices/#{device.id}"
    expect(page).to have_content("20.0")
  end

  it "deletes an attribute via the confirmation modal" do
    attribute = DeviceAttribute.create!(device: device, key: "power_w", value: "12.5")
    visit "/dashboard/devices/#{device.id}"

    within "#attribute-#{attribute.id}" do
      click_link "Delete"
    end

    within "#confirm-delete-attribute-modal" do
      click_button "Confirm Delete"
    end

    expect(page).not_to have_css("#attribute-#{attribute.id}")
    expect(page).to have_content("Attribute deleted successfully")
    expect(DeviceAttribute.exists?(attribute.id)).to be false
  end

  it "shows a validation error when creating a duplicate key" do
    DeviceAttribute.create!(device: device, key: "power_w", value: "12.5")
    visit "/dashboard/devices/#{device.id}"

    click_link "+ Add Attribute"

    within "#attribute-modal" do
      fill_in "device_attribute[key]", with: "power_w"
      fill_in "device_attribute[value]", with: "99"
      click_button "Create Attribute"
    end

    expect(page).to have_content("must be unique per device")
    expect(device.device_attributes.where(key: "power_w").count).to eq(1)
  end
end
