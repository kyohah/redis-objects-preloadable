# AR preload 内部実装調査

`redis_preload` を ActiveRecord の `preload` と同じ仕様にするための調査メモ。

調査対象: `/Users/kyohah/ghq/github.com/rails/rails`

---

## Rails preload の仕組み

### メタデータの保存場所

`preload(:foo)` で指定した情報は `@values` ハッシュの `:preload` キーに格納される。

```ruby
# activerecord/lib/active_record/relation/query_methods.rb

MULTI_VALUE_METHODS = [:includes, :eager_load, :preload, :select, :group, ...]

def preload(*args)
  spawn.preload!(*args)
end

def preload!(*args) # :nodoc:
  self.preload_values |= args  # @values[:preload] に union で追加
end
```

`@values` はメタプログラミングで自動生成されるアクセサを通じて操作され、`preload_values` は `@values.fetch(:preload, FROZEN_EMPTY_ARRAY)` に相当する。

---

### `reset` は `@values` を触らない

```ruby
# activerecord/lib/active_record/relation.rb:1226

def reset
  @future_result&.cancel
  @future_result = nil
  @delegate_to_model = false
  @to_sql = @arel = @loaded = @should_eager_load = nil
  @offsets = @take = nil
  @cache_keys = nil
  @cache_versions = nil
  @records = nil
  self
  # ↑ @values は一切触らない → preload メタデータは reset を跨いで生き残る
end
```

### `initialize_copy` (spawn の内部)

```ruby
# activerecord/lib/active_record/relation.rb:97

def initialize_copy(other)
  @values = @values.dup  # @values は shallow copy → preload メタデータが引き継がれる
  reset                  # @loaded/@records 等はクリア
end
```

`spawn` は `clone` を呼び `initialize_copy` が実行される。
`@values.dup` でメタデータが新リレーションに引き継がれ、`reset` でロード状態だけがクリアされる。

---

### preload が実際に走るタイミング

```
load()
 └─ if !loaded? || scheduled?
      exec_queries()
       ├─ exec_main_query()         ← SQL 発行
       ├─ instantiate_records()     ← AR インスタンス生成
       └─ preload_associations()    ← ★ここで preload が走る（毎回）
```

```ruby
# activerecord/lib/active_record/relation.rb:1435

def exec_queries(&block)
  rows = exec_main_query
  records = instantiate_records(rows, &block)
  preload_associations(records) unless skip_preloading_value  # ← フラグなし、毎回実行
  records
end

def preload_associations(records)
  preload = preload_values           # @values[:preload] を読む
  preload += includes_values unless eager_loading?
  preload.each do |associations|
    ActiveRecord::Associations::Preloader.new(records: records, associations: associations, ...).call
  end
end
```

**重要**: "既に preload した" というフラグは存在しない。
`exec_queries` は `load` が `!loaded?` のときしか呼ばれないため、二重実行は起きない。

---

### reset + load サイクルの全体フロー

```
Model.preload(:foo)
  → spawn → initialize_copy → @values.dup + reset
  → preload! → @values[:preload] = [:foo]

.load
  → !loaded? → exec_queries → preload_associations  ← 1回目

.reset
  → @loaded = nil, @records = nil  (@values[:preload] はそのまま)

.load
  → !loaded? → exec_queries → preload_associations  ← 2回目も正常に走る
```

---

## redis_preload との差分と修正方針

### 現状の問題

`redis_preload` は `@redis_preload_context_attached` フラグで「1回だけアタッチ」を制御しているが、このフラグが `reset` でクリアされない。

```ruby
# relation_extension.rb (現状)

def load
  result = super
  if !@redis_preload_context_attached && @redis_preload_names&.any? && loaded?
    @redis_preload_context_attached = true   # ← reset() で消えない
    context = PreloadContext.new(records, @redis_preload_names)
    records.each { ... }
  end
  result
end
```

### Rails の設計との対応

| Rails preload | redis_preload (現状) | redis_preload (修正後) |
|---|---|---|
| `@values[:preload]` に格納 | `@redis_preload_names` ivar に格納 | 同左（問題なし） |
| `reset` で `@values` は保持 | `@redis_preload_names` は保持される ✅ | 同左 |
| "実行済み" フラグなし | `@redis_preload_context_attached` が残存 ❌ | `reset` でクリア ✅ |
| `exec_queries` 内で毎回実行 | `load` で1回のみ | `reset` 後は再実行 ✅ |

### 修正方法

`RelationExtension` 内で `reset` をオーバーライドし、`@redis_preload_context_attached` をクリアする：

```ruby
def reset
  @redis_preload_context_attached = false
  super
end
```

これにより：
- `reset` 後の再 `load` でプリロードが正常に再実行される
- `spawn` は内部で `initialize_copy` → `reset` を呼ぶため、派生リレーションでもフラグが正しくリセットされる
- `load` が二重に呼ばれても `!loaded?` のガードで `exec_queries` は1回しか走らないため二重アタッチは起きない

### `@redis_preload_names` の伝播（現状で正しく動く）

```
Widget.redis_preload(:view_count)   # @redis_preload_names = [:view_count] をセット
  .where(active: true)              # spawn → clone → initialize_copy → @redis_preload_names が引き継がれる ✅
  .limit(10)                        # spawn → clone → 同上 ✅
```

`spawn` が `clone` を呼ぶため、チェーン全体で `@redis_preload_names` は保持される。

---

## 参照ソース

- `activerecord/lib/active_record/relation.rb`: `load`, `reset`, `initialize_copy`, `exec_queries`, `preload_associations`
- `activerecord/lib/active_record/relation/query_methods.rb`: `preload`, `preload!`, `MULTI_VALUE_METHODS`
