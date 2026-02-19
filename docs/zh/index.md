# redis-objects-preloadable

消除 ActiveRecord 模型中 [redis-objects](https://github.com/nateware/redis-objects) 的 N+1 Redis 调用。

提供 `redis_preload` 作用域，使用 `MGET`（用于 counter/value）和 `pipelined` 命令（用于 list/set/sorted_set/hash_key）批量加载 Redis::Objects 属性，遵循与 ActiveRecord `preload` 相同的设计理念。

## 安装

```ruby
gem "redis-objects-preloadable"
```

## 设置

在 `Redis::Objects` 之后 include `Redis::Objects::Preloadable`：

```ruby
class Pack < ApplicationRecord
  include Redis::Objects
  include Redis::Objects::Preloadable

  counter :cache_total_count, expiration: 15.minutes
  list    :recent_item_ids
  set     :tag_ids
end
```

## 使用方法

在任何 ActiveRecord 关系上链式调用 `redis_preload`：

```ruby
records = Pack.order(:id)
              .redis_preload(:cache_total_count, :recent_item_ids, :tag_ids)
              .limit(100)

records.each do |pack|
  pack.cache_total_count.value   # 已预加载，无 Redis 调用
  pack.recent_item_ids.values    # 已预加载
  pack.tag_ids.members           # 已预加载
end
```

不使用 `redis_preload` 时，访问 Redis 属性将回退到单独的 Redis 调用（原始行为）。

### 关联加载的记录预加载

`redis_preload` 适用于顶层关系。对于通过 `includes` / `preload` / `eager_load` 加载的记录，使用 `Redis::Objects::Preloadable.preload`：

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
    article.view_count.value     # 已预加载
    article.cached_summary.value # 已预加载
  end
end
```

### 延迟解析

预加载是延迟执行的。`redis_preload` 仅将元数据附加到关系上，直到首次访问预加载属性时才会发起 Redis 调用。届时，所有已加载记录的所有声明属性将在一次批量操作中获取。

## 支持的类型

| redis-objects 类型 | Redis 命令        | 预加载方法                                 |
|--------------------|-------------------|--------------------------------------------|
| `counter`          | MGET              | `value`, `nil?`                            |
| `value`            | MGET              | `value`, `nil?`                            |
| `list`             | LRANGE 0 -1       | `value`, `values`, `[]`, `length`, `empty?`|
| `set`              | SMEMBERS          | `members`, `include?`, `length`, `empty?`  |
| `sorted_set`       | ZRANGE WITHSCORES | `members`, `score`, `rank`, `length`       |
| `hash_key`         | HGETALL           | `all`, `[]`, `keys`, `values`              |

## 工作原理

1. `redis_preload(:attr1, :attr2)` 用 `RelationExtension` 扩展 AR 关系
2. 当关系加载时，`PreloadContext` 附加到每个 redis-objects 实例
3. 首次访问属性时，`PreloadContext#resolve!` 触发：
   - **counter/value** 类型：通过 `MGET` 批量获取
   - **list/set/sorted_set/hash_key** 类型：通过 `pipelined` 批量获取
4. 每个 redis-objects 实例通过 `preload!` 接收预加载值
5. 后续读取返回预加载值，无需访问 Redis

## 要求

- Ruby >= 3.1
- ActiveRecord >= 7.0
- redis-objects >= 1.7

## 许可证

MIT 许可证
