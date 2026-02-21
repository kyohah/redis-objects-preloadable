# frozen_string_literal: true

class Redis
  module Objects
    module Preloadable
      # ActiveSupport::Concern that integrates Preloadable into ActiveRecord models.
      #
      # Included automatically when a model does +include Redis::Objects::Preloadable+.
      # Overrides +.all+ to extend relations with {RelationExtension} and provides
      # the backward-compatible +read_redis_counter+ helper.
      #
      module ModelExtension
        extend ActiveSupport::Concern

        class_methods do
          # @api private
          def all(...)
            super(...).extending(Redis::Objects::Preloadable::RelationExtension)
          end
        end

        private

        # Backward-compatible helper for reading a counter with SQL fallback.
        #
        # If the counter has a preloaded value, it is returned directly.
        # Otherwise, checks Redis and falls back to the block (SQL query).
        #
        # With transparent preloading, this method is no longer necessary.
        # You can access +counter.value+ directly instead.
        #
        # @param _name [Symbol] the counter attribute name (unused in transparent mode)
        # @param counter [Redis::Counter] the counter instance
        # @yield SQL fallback block that returns the count
        # @return [Integer] the counter value
        #
        def read_redis_counter(_name, counter)
          if counter.instance_variable_defined?(:@preloaded_value)
            raw = counter.instance_variable_get(:@preloaded_value)
            return raw.to_i if raw

            count = yield
            counter.value = count
            return count
          end

          if counter.exists?
            counter.value.to_i
          else
            count = yield
            counter.value = count
            count
          end
        end
      end
    end
  end
end
