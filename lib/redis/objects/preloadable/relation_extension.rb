# frozen_string_literal: true

class Redis
  module Objects
    module Preloadable
      module RelationExtension
        def redis_preload(*names)
          spawn.tap { |r| r.instance_variable_set(:@redis_preload_names, names) }
        end

        def redis_preload_names
          @redis_preload_names || []
        end

        def load
          result = super

          if !@redis_preload_context_attached && @redis_preload_names&.any? && loaded?
            @redis_preload_context_attached = true
            context = PreloadContext.new(records, @redis_preload_names)
            records.each do |record|
              @redis_preload_names.each do |name|
                record.public_send(name).instance_variable_set(:@preload_context, context)
              end
            end
          end

          result
        end
      end
    end
  end
end
