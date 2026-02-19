# frozen_string_literal: true

class Redis
  module Objects
    module Preloadable
      MGET_TYPES = %i[counter value].freeze

      class PreloadContext
        def initialize(records, names)
          @records = records
          @names = names
          @resolved = false
        end

        def resolve!
          return if @resolved

          @resolved = true
          return if @records.empty?

          execute_preload
        end

        private

        def execute_preload
          klass = @records.first.class
          prefix = klass.redis_prefix
          ids = @records.map(&:id)
          redis_objects = klass.redis_objects

          mget_names = @names.select { |n| MGET_TYPES.include?(redis_objects.dig(n, :type)) }
          pipeline_names = @names - mget_names

          with_redis do |redis|
            fetch_mget(redis, prefix, ids, mget_names)
            fetch_pipeline(redis, prefix, ids, pipeline_names, redis_objects)
          end
        end

        def with_redis(&)
          redis_conn = ::Redis::Objects.redis
          if redis_conn.respond_to?(:with)
            redis_conn.with(&)
          else
            yield redis_conn
          end
        end

        def fetch_mget(redis, prefix, ids, names)
          return if names.empty?

          n = ids.size
          keys = names.flat_map { |name| ids.map { |id| "#{prefix}:#{id}:#{name}" } }
          values = redis.mget(*keys)

          names.each_with_index do |name, i|
            @records.zip(values[i * n, n]).each do |record, raw_value|
              record.public_send(name).preload!(raw_value)
            end
          end
        end

        def fetch_pipeline(redis, prefix, ids, names, redis_objects)
          return if names.empty?

          order, results = run_pipeline(redis, prefix, ids, names, redis_objects)
          apply_pipeline_results(order, results)
        end

        def run_pipeline(redis, prefix, ids, names, redis_objects)
          order = []
          results = redis.pipelined do |pipe|
            names.each do |name|
              type = redis_objects.dig(name, :type)
              ids.each do |id|
                order << [name, id]
                pipeline_command(pipe, "#{prefix}:#{id}:#{name}", type)
              end
            end
          end
          [order, results]
        end

        def pipeline_command(pipe, key, type)
          case type
          when :list       then pipe.lrange(key, 0, -1)
          when :set        then pipe.smembers(key)
          when :sorted_set then pipe.zrange(key, 0, -1, with_scores: true)
          when :dict       then pipe.hgetall(key)
          else                  pipe.get(key)
          end
        end

        def apply_pipeline_results(order, results)
          record_by_id = @records.index_by(&:id)
          order.each_with_index do |(name, id), idx|
            record_by_id[id]&.public_send(name)&.preload!(results[idx])
          end
        end
      end
    end
  end
end
