# Habitat smart home API
# Ruby 3.3 + Rails 7.1 + RSpec

FROM ruby:3.3-slim

WORKDIR /habitat

# Install dependencies
RUN apt-get update && apt-get install -y \
  build-essential \
  postgresql-client \
  && rm -rf /var/lib/apt/lists/*

# Copy Gemfile and Gemfile.lock (if exists)
# NOTE: A placeholder Gemfile must exist at build time (Phase 0 task 0.1b creates it).
# After rails new, this will be overwritten with the real Gemfile.
# This allows docker compose build to succeed before rails new generates the real Gemfile.
COPY Gemfile* ./

# Install gems (bundler already installed in ruby image)
# First build uses placeholder; after rails new, bundle install uses real Gemfile.
RUN bundle install

# Copy entire project
COPY . .

# Default command: start the Rails server
CMD ["rails", "server", "-b", "0.0.0.0"]
