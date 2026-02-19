# frozen_string_literal: true

source "https://rubygems.org"

gemspec

rails_version = ENV.fetch("RAILS_VERSION", nil)

gem "activerecord", "~> #{rails_version}.0" if rails_version

gem "connection_pool"
gem "rake", "~> 13.0"
gem "rspec", "~> 3.12"
gem "rubocop", "~> 1.21"
gem "sqlite3"
