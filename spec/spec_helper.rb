# frozen_string_literal: true

require "active_record"
require "redis-objects"
require "redis/objects/preloadable"

require_relative "support/test_models"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  config.before(:suite) do
    Redis::Objects.redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/15"))
  end

  config.before do
    Widget.delete_all
    Article.delete_all
    User.delete_all
  end

  config.after do
    Redis::Objects.redis.flushdb
  end
end
