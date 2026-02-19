# frozen_string_literal: true

class Redis
  module Objects
    module Preloadable
      module TypePatches
        # Prepended onto Redis::List to support preloaded values.
        # Fetched via LRANGE 0 -1 in a pipeline.
        module List
          # @api private
          def preload!(raw_value)
            @preloaded_value = raw_value || []
          end

          def value
            @preload_context&.resolve!
            return @preloaded_value if defined?(@preloaded_value)

            super
          end

          def values
            value
          end

          def [](index, length = nil)
            @preload_context&.resolve!
            if defined?(@preloaded_value)
              return length ? @preloaded_value[index, length] : @preloaded_value[index]
            end

            super
          end

          def length
            @preload_context&.resolve!
            return @preloaded_value.length if defined?(@preloaded_value)

            super
          end

          def empty?
            @preload_context&.resolve!
            return @preloaded_value.empty? if defined?(@preloaded_value)

            super
          end
        end
      end
    end
  end
end
