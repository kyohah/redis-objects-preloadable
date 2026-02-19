# frozen_string_literal: true

class Redis
  module Objects
    module Preloadable
      module TypePatches
        module SortedSet
          def preload!(raw_value)
            @preloaded_value = raw_value || []
          end

          def members(options = {})
            @preload_context&.resolve!
            if defined?(@preloaded_value)
              return @preloaded_value if options[:with_scores]

              return @preloaded_value.map(&:first)
            end

            super
          end

          def score(member)
            @preload_context&.resolve!
            if defined?(@preloaded_value)
              pair = @preloaded_value.find { |m, _| m == member.to_s }
              return pair&.last
            end

            super
          end

          def rank(member)
            @preload_context&.resolve!
            return @preloaded_value.index { |m, _| m == member.to_s } if defined?(@preloaded_value)

            super
          end

          def length
            @preload_context&.resolve!
            return @preloaded_value.length if defined?(@preloaded_value)

            super
          end
        end
      end
    end
  end
end
