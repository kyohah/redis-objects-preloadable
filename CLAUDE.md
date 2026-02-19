# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
bin/setup                                 # Install dependencies
bundle exec rspec                         # Run tests (requires local Redis on 127.0.0.1:6379)
bundle exec rspec spec/integration/       # Run integration tests only
bundle exec rspec spec/integration/counter_spec.rb  # Run a single test file
bundle exec rubocop                       # Lint
bundle exec rubocop -A                    # Auto-fix lint issues
bundle exec rake                          # Run tests + rubocop (default task)
bundle exec rake build                    # Build the gem
```

Tests use Redis DB 15 (`redis://127.0.0.1:6379/15`) by default. Override via `REDIS_URL` env var.

## Code Style

RuboCop is enforced. Key rules:
- Double quotes for string literals
- Target Ruby version: 3.1
- `class Redis` (not `module Redis`) to open the Redis namespace — redis gem defines Redis as a class

## Architecture

This gem eliminates N+1 Redis calls for `redis-objects` attributes on ActiveRecord models by providing a `redis_preload` scope that batch-loads values via MGET/pipeline.

### Key Files

```
lib/redis/objects/preloadable.rb              # Entry point: requires, prepends type patches
lib/redis/objects/preloadable/version.rb      # VERSION constant
lib/redis/objects/preloadable/preload_context.rb    # Core: MGET + pipeline batch loading
lib/redis/objects/preloadable/relation_extension.rb # AR Relation: redis_preload scope + lazy load hook
lib/redis/objects/preloadable/model_extension.rb    # Concern: class_methods(def all) + read_redis_counter
lib/redis/objects/preloadable/type_patches/         # prepend patches for 6 redis-objects types
```

### Data Flow

1. `Model.all` is overridden to extend relations with `RelationExtension`
2. `redis_preload(:counter_name, :list_name)` stores names on the relation via `spawn`
3. When `load` is called, a `PreloadContext` is created and attached to each redis-objects instance via `@preload_context`
4. On first attribute read (e.g., `counter.value`), the type patch calls `@preload_context.resolve!`
5. `resolve!` fetches ALL preloaded attributes for ALL records in one batch:
   - counter/value types via `MGET`
   - list/set/sorted_set/hash_key types via `pipelined`
6. Values are injected into redis-objects instances via `preload!`

### redis-objects Type Keys

The `redis_objects` class method returns type keys that differ from the DSL method names:
- `counter` -> `:counter`, `value` -> `:value`, `list` -> `:list`
- `set` -> `:set`, `sorted_set` -> `:sorted_set`
- `hash_key` -> `:dict` (not `:hash_key`)

## Dependencies

- `redis-objects` >= 1.7 (runtime)
- `activerecord` >= 7.0 (runtime)
- Ruby >= 3.1
