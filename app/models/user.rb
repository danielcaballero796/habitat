class User < ApplicationRecord
  has_secure_password  # Adds password= and authenticate() via bcrypt

  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 8 }
end
