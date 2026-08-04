require "rails_helper"

RSpec.describe "Dashboard login", type: :system do
  let!(:user) { User.create!(email: "admin@habitat.local", password: "secure123") }

  it "logs in with valid credentials and lands on the dashboard" do
    visit "/login"
    fill_in "Email", with: "admin@habitat.local"
    fill_in "Password", with: "secure123"
    click_button "Log In"

    expect(page).to have_current_path("/dashboard")
    expect(page).to have_content("Welcome, admin@habitat.local")
  end

  it "shows an error and stays on the login page with invalid credentials" do
    visit "/login"
    fill_in "Email", with: "admin@habitat.local"
    fill_in "Password", with: "wrong-password"
    click_button "Log In"

    expect(page).to have_current_path("/login")
    expect(page).to have_content("Invalid email or password")
  end

  it "redirects an unauthenticated visitor to /login" do
    visit "/dashboard"

    expect(page).to have_current_path("/login")
  end

  it "logs out and requires login again for the dashboard" do
    sign_in(user, password: "secure123")
    expect(page).to have_current_path("/dashboard")

    click_button "Logout"

    expect(page).to have_current_path("/login")

    visit "/dashboard"
    expect(page).to have_current_path("/login")
  end
end
