# frozen_string_literal: true

require_relative "lib/redis/objects/preloadable/version"

Gem::Specification.new do |spec|
  spec.name    = "redis-objects-preloadable"
  spec.version = Redis::Objects::Preloadable::VERSION
  spec.authors = ["kyohah"]
  spec.email   = ["3257272+kyohah@users.noreply.github.com"]

  spec.summary     = "Eliminate N+1 Redis calls for redis-objects in ActiveRecord models"
  spec.description = <<~DESC
    Provides batch loading (MGET / pipeline) for Redis::Objects attributes on
    ActiveRecord models, following the same design as ActiveRecord's `preload`.
    Supports counter, value, list, set, sorted_set, and hash_key types.
  DESC
  spec.homepage = "https://github.com/kyohah/redis-objects-preloadable"
  spec.license  = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*", "README.md", "CHANGELOG.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "redis-objects", ">= 1.7"
end
