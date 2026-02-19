# frozen_string_literal: true

class Redis
  module Objects
    module Preloadable
      module ModelExtension
        extend ActiveSupport::Concern

        class_methods do
          def all
            super.extending(Redis::Objects::Preloadable::RelationExtension)
          end
        end

        private

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
