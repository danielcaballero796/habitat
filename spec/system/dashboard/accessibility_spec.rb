require "rails_helper"

RSpec.describe "Dashboard modal accessibility", type: :system do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }
  let!(:device) { Device.create!(name: "Living Room Hub", type: "hub", brand: "Samsung", room: "Living Room") }

  before do
    sign_in(user, password: "secure123")
    visit "/dashboard/devices"
  end

  it "moves focus into the modal when it opens" do
    click_link "+ Add New Device"

    expect(page).to have_css("#device-modal.open")
    expect(page.evaluate_script("document.activeElement.closest('#device-modal') !== null")).to be true
  end

  it "keeps Tab focus cycling within the open modal (does not escape to the background page)" do
    click_link "+ Add New Device"
    expect(page).to have_css("#device-modal.open")

    # Tab far more times than there are focusable elements inside the modal;
    # if focus escaped to the background it would land on a page element
    # outside #device-modal (e.g. a table row link).
    20.times { page.send_keys(:tab) }

    expect(page.evaluate_script("document.activeElement.closest('#device-modal') !== null")).to be true
  end

  it "returns focus to the trigger element when the modal is closed with the close button" do
    click_link "+ Add New Device"
    expect(page).to have_css("#device-modal.open")

    within "#device-modal" do
      find(".modal-close").click
    end

    expect(page).not_to have_css("#device-modal.open")
    expect(page.evaluate_script("document.activeElement.textContent")).to include("Add New Device")
  end

  it "closes the modal and returns focus to the trigger when Escape is pressed" do
    click_link "+ Add New Device"
    expect(page).to have_css("#device-modal.open")

    page.send_keys(:escape)

    expect(page).not_to have_css("#device-modal.open")
    expect(page.evaluate_script("document.activeElement.textContent")).to include("Add New Device")
  end

  it "traps focus and returns it to the trigger for the delete-confirmation modal" do
    within "#device-#{device.id}" do
      click_link "Delete"
    end

    expect(page).to have_css("#confirm-delete-modal.open")
    expect(page.evaluate_script("document.activeElement.closest('#confirm-delete-modal') !== null")).to be true

    page.send_keys(:escape)

    expect(page).not_to have_css("#confirm-delete-modal.open")
    expect(page.evaluate_script("document.activeElement.textContent")).to include("Delete")
  end
end
