# frozen_string_literal: true

class Redis
  module Objects
    module Preloadable
      module TypePatches
        module Value
          def preload!(raw_value)
            @preloaded_value = raw_value
          end

          def value
            @preload_context&.resolve!
            return @preloaded_value if defined?(@preloaded_value)

            super
          end

          def nil?
            @preload_context&.resolve!
            return @preloaded_value.nil? if defined?(@preloaded_value)

            super
          end
        end
      end
    end
  end
end
