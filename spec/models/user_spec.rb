require "rails_helper"

RSpec.describe User, type: :model do
  describe "creation" do
    it "creates a User with email and password" do
      user = User.create(email: "admin@habitat.local", password: "secure123")
      expect(user).to be_persisted
      expect(user.email).to eq "admin@habitat.local"
      expect(user.password_digest).not_to eq "secure123"  # bcrypt hash
    end
  end

  describe "email uniqueness" do
    it "requires unique email" do
      User.create!(email: "admin@habitat.local", password: "secure123")
      user2 = User.new(email: "admin@habitat.local", password: "secure123")
      expect(user2.save).to be false
      expect(user2.errors[:email]).not_to be_empty
    end
  end

  describe "password authentication" do
    it "authenticates with correct password" do
      user = User.create!(email: "admin@habitat.local", password: "secure123")
      expect(user.authenticate("secure123")).to eq user
    end

    it "rejects incorrect password" do
      user = User.create!(email: "admin@habitat.local", password: "secure123")
      expect(user.authenticate("wrongpassword")).to be false
    end
  end

  describe "password validation" do
    it "requires password to be present" do
      user = User.new(email: "admin@habitat.local", password: "")
      expect(user.save).to be false
      expect(user.errors[:password]).not_to be_empty
    end

    it "requires password to be at least 8 characters" do
      user = User.new(email: "admin@habitat.local", password: "short")
      expect(user.save).to be false
      expect(user.errors[:password]).not_to be_empty
    end
  end
end
