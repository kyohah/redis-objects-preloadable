# frozen_string_literal: true

class Redis
  module Objects
    module Preloadable
      # Extends ActiveRecord::Relation with +redis_preload+ scope.
      #
      # This module is automatically mixed into relations via
      # {ModelExtension::ClassMethods#all}.
      #
      # @example
      #   Widget.where(active: true).redis_preload(:view_count, :tag_ids).each do |w|
      #     w.view_count.value  # preloaded
      #   end
      #
      module RelationExtension
        # Declare redis-objects attributes to batch-preload when the relation loads.
        #
        # Can be chained with other ActiveRecord scopes. Preloading is lazy:
        # no Redis calls until the first attribute access.
        #
        # @param names [Array<Symbol>] redis-objects attribute names
        # @return [ActiveRecord::Relation] a new relation with preload metadata
        #
        # @example
        #   Widget.order(:id).redis_preload(:view_count).limit(100)
        #
        def redis_preload(*names)
          spawn.tap { |r| r.instance_variable_set(:@redis_preload_names, names) }
        end

        # @return [Array<Symbol>] the redis-objects attribute names to preload
        def redis_preload_names
          @redis_preload_names || []
        end

        # @api private
        def reset
          @redis_preload_context_attached = false
          super
        end

        # @api private
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
