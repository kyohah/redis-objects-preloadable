# frozen_string_literal: true

class Redis
  module Objects
    module Preloadable
      module TypePatches
        module HashKey
          def preload!(raw_value)
            @preloaded_value = raw_value || {}
          end

          def all
            @preload_context&.resolve!
            return @preloaded_value if defined?(@preloaded_value)

            super
          end

          def [](key)
            @preload_context&.resolve!
            return @preloaded_value[key.to_s] if defined?(@preloaded_value)

            super
          end

          def keys
            @preload_context&.resolve!
            return @preloaded_value.keys if defined?(@preloaded_value)

            super
          end

          def values
            @preload_context&.resolve!
            return @preloaded_value.values if defined?(@preloaded_value)

            super
          end
        end
      end
    end
  end
end
