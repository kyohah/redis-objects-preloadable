## [Unreleased]

## [0.1.2] - 2026-02-22

- Fix `RelationExtension#reset` to clear `@redis_preload_context_attached`, so `redis_preload` context is correctly re-attached on every `load` after `reset` (matches AR `.includes` behavior)
- Document that `record.reload` does not clear preloaded Redis values (by design)

## [0.1.1] - 2026-02-22

- Fix Rails 8.1 / Ruby 3.4 compatibility: forward all arguments in `ModelExtension.all` override to avoid `ArgumentError` when `ActiveRecord::Persistence#_find_record` calls `all(all_queries: ...)` ([#fix](https://github.com/kyohah/redis-objects-preloadable/issues))

## [0.1.0] - 2026-02-20

- Initial release
