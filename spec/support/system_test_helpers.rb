# Shared helpers for Capybara system specs (spec/system/**). System specs
# drive a real browser session, so authentication must go through the
# actual /login form (unlike request specs, which can `post "/login"`
# directly and reuse the Rack test session).
module SystemTestHelpers
  def sign_in(user, password:)
    visit "/login"
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log In"

    # `click_button` returns as soon as the click event dispatches, not once
    # the resulting Turbo Drive visit/redirect has actually settled and the
    # session cookie is applied. Without waiting here, a caller's immediate
    # follow-up `visit` can race ahead of that in-flight navigation and hit
    # the next page before the session cookie exists yet, landing back on
    # /login ("Please log in to continue") — an intermittent flake, not a
    # real app bug. Block until the redirect chain (/dashboard -> /dashboard/devices)
    # has settled.
    expect(page).to have_current_path("/dashboard/devices")
  end
end

RSpec.configure do |config|
  config.include SystemTestHelpers, type: :system
end
