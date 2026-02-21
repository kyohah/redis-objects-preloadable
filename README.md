# redis-objects-preloadable

[English](README.md) | [日本語](docs/ja/index.md) | [中文](docs/zh/index.md) | [Français](docs/fr/index.md) | [Deutsch](docs/de/index.md)

Eliminate N+1 Redis calls for [redis-objects](https://github.com/nateware/redis-objects) in ActiveRecord models.

Provides `redis_preload` scope that batch-loads Redis::Objects attributes using `MGET` (for counter/value) and `pipelined` commands (for list/set/sorted_set/hash_key), following the same design as ActiveRecord's `preload`.

## Installation

```ruby
gem "redis-objects-preloadable"
```

## Setup

Include `Redis::Objects::Preloadable` in your model after `Redis::Objects`:

```ruby
class Pack < ApplicationRecord
  include Redis::Objects
  include Redis::Objects::Preloadable

  counter :cache_total_count, expiration: 15.minutes
  list    :recent_item_ids
  set     :tag_ids
end
```

## Usage

Chain `redis_preload` onto any ActiveRecord relation:

```ruby
records = Pack.order(:id)
              .redis_preload(:cache_total_count, :recent_item_ids, :tag_ids)
              .limit(100)

records.each do |pack|
  pack.cache_total_count.value   # preloaded, no Redis call
  pack.recent_item_ids.values    # preloaded
  pack.tag_ids.members           # preloaded
end
```

Without `redis_preload`, accessing Redis attributes falls back to individual Redis calls (original behavior).

### Preloading on Association-Loaded Records

`redis_preload` works on top-level relations. For records loaded via `includes` / `preload` / `eager_load`, use `Redis::Objects::Preloadable.preload`:

```ruby
class User < ApplicationRecord
  has_many :articles
end

class Article < ApplicationRecord
  include Redis::Objects
  include Redis::Objects::Preloadable

  counter :view_count
  value   :cached_summary
end

users = User.includes(:articles).load

# Batch-preload Redis attributes on the associated records
articles = users.flat_map(&:articles)
Redis::Objects::Preloadable.preload(articles, :view_count, :cached_summary)

users.each do |user|
  user.articles.each do |article|
    article.view_count.value     # preloaded, no Redis call
    article.cached_summary.value # preloaded
  end
end
```

`Redis::Objects::Preloadable.preload` accepts any array of records, so it works in any context — not just associations.

### Lazy Resolution

Preloading is lazy. The `redis_preload` scope attaches metadata to the relation, but no Redis calls are made until you first access a preloaded attribute. At that point, all declared attributes for all loaded records are fetched in a single batch.

## Supported Types

| redis-objects type | Redis command     | Preloaded methods                          |
|--------------------|-------------------|--------------------------------------------|
| `counter`          | MGET              | `value`, `nil?`                            |
| `value`            | MGET              | `value`, `nil?`                            |
| `list`             | LRANGE 0 -1       | `value`, `values`, `[]`, `length`, `empty?`|
| `set`              | SMEMBERS          | `members`, `include?`, `length`, `empty?`  |
| `sorted_set`       | ZRANGE WITHSCORES | `members`, `score`, `rank`, `length`       |
| `hash_key`         | HGETALL           | `all`, `[]`, `keys`, `values`              |

## How It Works

1. `redis_preload(:attr1, :attr2)` extends the AR relation with `RelationExtension`
2. When the relation is loaded, a `PreloadContext` is attached to each redis-objects instance
3. On first attribute access, `PreloadContext#resolve!` fires:
   - **counter/value** types: batched via `MGET`
   - **list/set/sorted_set/hash_key** types: batched via `pipelined`
4. Each redis-objects instance receives its preloaded value via `preload!`
5. Subsequent reads return the preloaded value without hitting Redis

The type patches are applied via `prepend` on `Redis::Counter`, `Redis::Value`, `Redis::List`, `Redis::Set`, `Redis::SortedSet`, and `Redis::HashKey`.

## Limitations

### `record.reload` does not clear preloaded values

`reload` refreshes DB columns only. Preloaded Redis values remain cached on the redis-objects instances and are **not** updated.

```ruby
widget = Widget.redis_preload(:view_count).first
widget.view_count.value  # => 5 (preloaded)

# Another process increments the counter in Redis...

widget.reload
widget.view_count.value  # => 5 (still the preloaded value — NOT refreshed)
```

If you need a fresh Redis value after `reload`, fetch the record again without preloading:

```ruby
Widget.find(widget.id).view_count.value  # => hits Redis directly
```

## Backward Compatibility: `read_redis_counter`

If your models use the `read_redis_counter` helper (from the original Concern-based approach), it continues to work. With transparent preloading, you can remove explicit `read_redis_counter` calls and access `counter.value` directly.

## Requirements

- Ruby >= 3.1
- ActiveRecord >= 7.0
- redis-objects >= 1.7

## Development

```bash
bin/setup           # install dependencies
bundle exec rspec   # run tests (requires local Redis)
bundle exec rubocop # lint
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
