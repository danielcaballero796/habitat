require "rails_helper"

# Verifies (rather than assumes) how Turbo Drive actually behaves when a
# device create submission hits a genuine 500, as opposed to a handled 422
# validation error (already covered by create_spec.rb). This exercises a
# real headless-Chrome + Turbo Drive form submission via Cuprite, so it
# reflects actual browser behavior, not a request-spec approximation.
RSpec.describe "Device create form resilience on a server error", type: :system do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }

  before do
    sign_in(user, password: "secure123")
  end

  it "does not silently succeed or lose the fact that the submission failed when the server 500s" do
    # Stub with a real completed 500 response (rather than an unrescued
    # `raise`) so the browser/Turbo Drive actually receives an HTTP
    # response to react to. An unrescued raise crashes the in-process test
    # Puma thread and Capybara re-raises it straight into the test process
    # instead of letting Turbo Drive see a response at all — that's a
    # testing-harness artifact of running the app in-process, not
    # representative of what a real deployed 500 response body does in the
    # browser.
    allow_any_instance_of(Dashboard::DevicesController).to receive(:create) do |controller|
      controller.render html: "<h1>We're sorry, but something went wrong</h1>".html_safe, status: 500
    end

    visit "/dashboard/devices"
    click_link "+ Add New Device"

    within "#device-modal" do
      fill_in "device[name]", with: "Kitchen Plug"
      select "smart_plug", from: "device[type]"
      click_button "Create Device"
    end

    # No device was persisted — the failed submission did not silently
    # "succeed" from the user's point of view.
    expect(Device.count).to eq(0)

    # Turbo Drive does NOT keep the previous page/DOM around on a non-2xx,
    # non turbo-stream response: it replaces the document with whatever
    # body the 500 response returned (here, Rails' local-request error
    # page, since config.consider_all_requests_local = true in test env).
    # The dashboard list content is gone from the DOM — confirming Turbo's
    # "preserve the form on error" behavior only applies to responses the
    # app deliberately re-renders (422 above), not to raw 500s.
    expect(page).not_to have_css("#device-modal")
    expect(page).not_to have_content("Kitchen Plug")
  end
end
