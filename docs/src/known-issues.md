# Known Issues

## Potential bugs identified in v0.1.x

---

### 1. `reset` 後の再 `load` でプリロードが無効化される

**深刻度**: 高（パフォーマンス劣化・N+1 再発）
**ステータス**: 未修正

#### 現象

`RelationExtension#load` が内部で使う `@redis_preload_context_attached` フラグが、`ActiveRecord::Relation#reset` 後もクリアされない。
そのため `reset` + `load` を繰り返すと 2 回目以降の `load` でプリロードコンテキストが新レコードにアタッチされず、N+1 Redis 問題が再発する。

#### 調査結果（spec で確認済み）

`spec/integration/relation_reset_spec.rb` で以下を確認した:

| ケース | `@preload_context` | `mget` 呼び出し |
|--------|-------------------|----------------|
| 初回 `load` | ✅ アタッチされる | ✅ 1 回（バッチ） |
| `reset` + `load` 後 | ❌ アタッチされない | ❌ 0 回（個別 `GET` へフォールバック） |

AR の `.includes` は `reset` 後も毎回 association を再プリロードする（正しい動作）が、`redis_preload` はそうならない。

**値の正確性への影響はない**。個別の Redis `GET` にフォールバックするため値は正しく返る。影響はパフォーマンスのみ。

#### 根本原因

```ruby
# relation_extension.rb
def load
  result = super
  if !@redis_preload_context_attached && @redis_preload_names&.any? && loaded?
    @redis_preload_context_attached = true   # ← reset でクリアされない
    ...
  end
  result
end
```

AR の `reset` は `@records = nil` / `@loaded = false` をクリアするが、カスタムインスタンス変数 `@redis_preload_context_attached` はクリアしない。

#### 修正案

`RelationExtension` 内で `reset` をオーバーライドして `@redis_preload_context_attached` をリセットする:

```ruby
def reset
  @redis_preload_context_attached = false
  super
end
```

---

### 2. `record.reload` 後にプリロード済みの古い値が返る（仕様）

**深刻度**: 低（仕様として許容）
**ステータス**: 設計上の制約として文書化済み

#### 動作

`record.reload` は DB 属性を最新化するが、redis-objects の preload 済み値はそのまま残る。

```ruby
widget = Widget.redis_preload(:view_count).first
widget.view_count.value  # → 5（preloaded）

# 別プロセスが Redis の値を変更...

widget.reload
widget.view_count.value  # → 5（preloaded value がそのまま返る）
```

#### 設計判断

redis-objects 属性は DB と独立したストアであり、`reload` のスコープ（DB の再読み込み）外と判断した。`reload` 後に最新の Redis 値が必要な場合は、レコードを新たに取得するか、preload を使わず直接アクセスすること。

```ruby
# preload なしで直接アクセスすれば常に最新値
Widget.find(widget.id).view_count.value  # → Redis から直接取得
```

---

### 3. `SortedSet#members` がオプション引数を無視する

**深刻度**: 中（サイレントな正確性バグ）
**ステータス**: 未修正

#### 現象

redis-objects の `SortedSet#members` は `:start`/`:stop`/`:range_by_score` 等のオプションを受け取るが、プリロード版は `:with_scores` のみ考慮しており、それ以外のオプションは無視してフル配列を返す。

```ruby
# type_patches/sorted_set.rb
def members(options = {})
  if defined?(@preloaded_value)
    return @preloaded_value if options[:with_scores]
    return @preloaded_value.map(&:first)  # ← start/stop を無視
  end
  super
end
```

#### 修正案

オプションが `:with_scores` 以外を含む場合は `super` にフォールバックする:

```ruby
def members(options = {})
  if defined?(@preloaded_value) && (options.keys - [:with_scores]).empty?
    return @preloaded_value if options[:with_scores]
    return @preloaded_value.map(&:first)
  end
  super
end
```

---

### 4. 存在しない属性名を `redis_preload` に渡すとサイレントに誤動作する

**深刻度**: 低〜中
**ステータス**: 未修正

#### 現象

`redis_preload(:nonexistent)` のように定義されていない属性名を渡しても例外が起きない。
`redis_objects.dig(name, :type)` が `nil` を返し、`pipeline_command` の `else` ブランチで `pipe.get(key)` が実行され、結果は `nil` として `preload!` される。

#### 修正案

`PreloadContext` の初期化時または `execute_preload` 冒頭で属性名を検証する:

```ruby
unknown = names.reject { |n| redis_objects.key?(n) }
raise ArgumentError, "Unknown redis_preload attributes: #{unknown}" if unknown.any?
```

---

### 5. STI 混在レコード配列で誤った prefix が使用される

**深刻度**: 低（エッジケース）
**ステータス**: 未修正

#### 現象

`@records.first.class` で prefix を決定しているため、STI で親クラス/子クラスが混在する配列を渡すと、一部レコードに誤ったキーが使われる。

---

## 修正済み

### Rails 8.1 / Ruby 3.4 互換性: `all` のキーワード引数転送 (v0.1.1)

Rails 8.1.2 で `_find_record` が `self.class.all(all_queries: all_queries)` とキーワード引数付きで `all` を呼ぶように変更された。
`ModelExtension.all` が引数なしで定義されていたため、`record.reload` 呼び出し時に `ArgumentError` が発生していた。

`def all(...)` / `super(...)` の forwarding 構文で修正済み。
詳細: [`lib/redis/objects/preloadable/model_extension.rb`](../../lib/redis/objects/preloadable/model_extension.rb)
