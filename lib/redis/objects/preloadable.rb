# frozen_string_literal: true

require "active_record"
require "redis-objects"

require_relative "preloadable/version"
require_relative "preloadable/type_patches/counter"
require_relative "preloadable/type_patches/value"
require_relative "preloadable/type_patches/list"
require_relative "preloadable/type_patches/set"
require_relative "preloadable/type_patches/sorted_set"
require_relative "preloadable/type_patches/hash_key"
require_relative "preloadable/preload_context"
require_relative "preloadable/relation_extension"
require_relative "preloadable/model_extension"

Redis::Counter.prepend(Redis::Objects::Preloadable::TypePatches::Counter)
Redis::Value.prepend(Redis::Objects::Preloadable::TypePatches::Value)
Redis::List.prepend(Redis::Objects::Preloadable::TypePatches::List)
Redis::Set.prepend(Redis::Objects::Preloadable::TypePatches::Set)
Redis::SortedSet.prepend(Redis::Objects::Preloadable::TypePatches::SortedSet)
Redis::HashKey.prepend(Redis::Objects::Preloadable::TypePatches::HashKey)

# Redis::Objects::Preloadable eliminates N+1 Redis calls for redis-objects
# attributes on ActiveRecord models.
#
# It provides two APIs:
#
# 1. +redis_preload+ scope on ActiveRecord relations
# 2. +Redis::Objects::Preloadable.preload+ for arbitrary record arrays
#
# == Basic usage
#
#   class Pack < ApplicationRecord
#     include Redis::Objects
#     include Redis::Objects::Preloadable
#
#     counter :cache_total_count
#     list    :recent_item_ids
#   end
#
#   # Scope-based (top-level queries)
#   Pack.redis_preload(:cache_total_count, :recent_item_ids).limit(100).each do |pack|
#     pack.cache_total_count.value  # preloaded via MGET
#     pack.recent_item_ids.values   # preloaded via pipeline
#   end
#
# == Association-loaded records
#
#   users = User.includes(:articles).load
#   articles = users.flat_map(&:articles)
#   Redis::Objects::Preloadable.preload(articles, :view_count)
#
class Redis
  module Objects
    module Preloadable
      def self.included(base)
        base.include(ModelExtension)
      end

      # Batch-preload Redis::Objects attributes on an array of records.
      #
      # Use this for records loaded outside of +redis_preload+ scope,
      # such as association-loaded records via +includes+.
      #
      # Preloading is lazy: no Redis calls are made until the first
      # attribute access on any of the records.
      #
      # @param records [Array<ActiveRecord::Base>, ActiveRecord::Relation] records to preload
      # @param names [Array<Symbol>] redis-objects attribute names to preload
      # @return [Array<ActiveRecord::Base>] the same records array
      #
      # @example Preload on association-loaded records
      #   users = User.includes(:articles).load
      #   articles = users.flat_map(&:articles)
      #   Redis::Objects::Preloadable.preload(articles, :view_count, :cached_summary)
      #
      def self.preload(records, *names)
        records = records.to_a
        return records if records.empty? || names.empty?

        context = PreloadContext.new(records, names)
        records.each do |record|
          names.each do |name|
            record.public_send(name).instance_variable_set(:@preload_context, context)
          end
        end
        records
      end
    end
  end
end
