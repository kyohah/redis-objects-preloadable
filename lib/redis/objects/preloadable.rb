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

class Redis
  module Objects
    module Preloadable
      def self.included(base)
        base.include(ModelExtension)
      end

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
