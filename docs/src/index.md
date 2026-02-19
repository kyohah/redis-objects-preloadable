# redis-objects-preloadable

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

articles = users.flat_map(&:articles)
Redis::Objects::Preloadable.preload(articles, :view_count, :cached_summary)

users.each do |user|
  user.articles.each do |article|
    article.view_count.value     # preloaded, no Redis call
    article.cached_summary.value # preloaded
  end
end
```

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

## Requirements

- Ruby >= 3.1
- ActiveRecord >= 7.0
- redis-objects >= 1.7

## License

MIT License
