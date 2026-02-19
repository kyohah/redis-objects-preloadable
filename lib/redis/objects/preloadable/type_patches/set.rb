# frozen_string_literal: true

class Redis
  module Objects
    module Preloadable
      module TypePatches
        module Set
          def preload!(raw_value)
            @preloaded_value = raw_value || []
          end

          def members
            @preload_context&.resolve!
            return @preloaded_value if defined?(@preloaded_value)

            super
          end

          def include?(member)
            @preload_context&.resolve!
            return @preloaded_value.include?(member.to_s) if defined?(@preloaded_value)

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
