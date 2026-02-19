# redis-objects-preloadable

[English](../../README.md) | [日本語](index.md) | [中文](../zh/index.md) | [Français](../fr/index.md) | [Deutsch](../de/index.md)

[redis-objects](https://github.com/nateware/redis-objects) を使った ActiveRecord モデルの N+1 Redis 呼び出しを解消します。

`redis_preload` スコープにより、Redis::Objects の属性を `MGET`（counter/value）や `pipelined`（list/set/sorted_set/hash_key）でバッチ取得します。ActiveRecord の `preload` と同じ設計思想です。

## インストール

```ruby
gem "redis-objects-preloadable"
```

## セットアップ

`Redis::Objects` の後に `Redis::Objects::Preloadable` を include します：

```ruby
class Pack < ApplicationRecord
  include Redis::Objects
  include Redis::Objects::Preloadable

  counter :cache_total_count, expiration: 15.minutes
  list    :recent_item_ids
  set     :tag_ids
end
```

## 使い方

ActiveRecord の Relation に `redis_preload` をチェーンするだけです：

```ruby
records = Pack.order(:id)
              .redis_preload(:cache_total_count, :recent_item_ids, :tag_ids)
              .limit(100)

records.each do |pack|
  pack.cache_total_count.value   # プリロード済み、Redis 呼び出しなし
  pack.recent_item_ids.values    # プリロード済み
  pack.tag_ids.members           # プリロード済み
end
```

`redis_preload` なしの場合は、従来通り個別の Redis 呼び出しにフォールバックします。

### アソシエーション経由のレコード

`includes` / `preload` / `eager_load` で読み込んだ関連レコードには `Redis::Objects::Preloadable.preload` を使います：

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

# 関連レコードの Redis 属性をバッチプリロード
articles = users.flat_map(&:articles)
Redis::Objects::Preloadable.preload(articles, :view_count, :cached_summary)

users.each do |user|
  user.articles.each do |article|
    article.view_count.value     # プリロード済み
    article.cached_summary.value # プリロード済み
  end
end
```

### 遅延解決

プリロードは遅延実行されます。`redis_preload` はメタデータを Relation に付与するだけで、最初の属性アクセス時にまとめてバッチ取得します。

## 対応する型

| redis-objects の型 | Redis コマンド    | プリロード対象メソッド                     |
|--------------------|-------------------|--------------------------------------------|
| `counter`          | MGET              | `value`, `nil?`                            |
| `value`            | MGET              | `value`, `nil?`                            |
| `list`             | LRANGE 0 -1       | `value`, `values`, `[]`, `length`, `empty?`|
| `set`              | SMEMBERS          | `members`, `include?`, `length`, `empty?`  |
| `sorted_set`       | ZRANGE WITHSCORES | `members`, `score`, `rank`, `length`       |
| `hash_key`         | HGETALL           | `all`, `[]`, `keys`, `values`              |

## 仕組み

1. `redis_preload(:attr1, :attr2)` が AR Relation を `RelationExtension` で拡張
2. Relation の `load` 時に `PreloadContext` を各 redis-objects インスタンスに紐付け
3. 最初の属性アクセスで `PreloadContext#resolve!` が発火：
   - **counter/value** → `MGET` でバッチ取得
   - **list/set/sorted_set/hash_key** → `pipelined` でバッチ取得
4. 各 redis-objects インスタンスに `preload!` でプリロード値をセット
5. 以降の読み取りはプリロード値を返す（Redis 呼び出しなし）

## 後方互換: `read_redis_counter`

既存の `read_redis_counter` ヘルパーを使っている場合もそのまま動作します。透過的プリロードにより、`read_redis_counter` を削除して `counter.value` を直接呼び出すことができます。

## 要件

- Ruby >= 3.1
- ActiveRecord >= 7.0
- redis-objects >= 1.7

## 開発

```bash
bin/setup           # 依存関係のインストール
bundle exec rspec   # テスト実行（ローカル Redis が必要）
bundle exec rubocop # Lint
```

## ライセンス

[MIT License](https://opensource.org/licenses/MIT)
