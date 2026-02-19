# redis-objects-preloadable

Eliminierung von N+1 Redis-Aufrufen für [redis-objects](https://github.com/nateware/redis-objects) in ActiveRecord-Modellen.

Bietet einen `redis_preload`-Scope, der Redis::Objects-Attribute mittels `MGET` (für counter/value) und `pipelined`-Befehlen (für list/set/sorted_set/hash_key) im Batch lädt, nach dem gleichen Designprinzip wie ActiveRecords `preload`.

## Installation

```ruby
gem "redis-objects-preloadable"
```

## Einrichtung

Fügen Sie `Redis::Objects::Preloadable` nach `Redis::Objects` in Ihr Modell ein:

```ruby
class Pack < ApplicationRecord
  include Redis::Objects
  include Redis::Objects::Preloadable

  counter :cache_total_count, expiration: 15.minutes
  list    :recent_item_ids
  set     :tag_ids
end
```

## Verwendung

Verketten Sie `redis_preload` mit jeder ActiveRecord-Relation:

```ruby
records = Pack.order(:id)
              .redis_preload(:cache_total_count, :recent_item_ids, :tag_ids)
              .limit(100)

records.each do |pack|
  pack.cache_total_count.value   # vorgeladen, kein Redis-Aufruf
  pack.recent_item_ids.values    # vorgeladen
  pack.tag_ids.members           # vorgeladen
end
```

Ohne `redis_preload` werden Redis-Attribute wie gewohnt einzeln abgerufen (Standardverhalten).

### Vorladen von über Assoziationen geladenen Datensätzen

`redis_preload` funktioniert bei Top-Level-Relationen. Für über `includes` / `preload` / `eager_load` geladene Datensätze verwenden Sie `Redis::Objects::Preloadable.preload`:

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
    article.view_count.value     # vorgeladen
    article.cached_summary.value # vorgeladen
  end
end
```

### Verzögerte Auflösung

Das Vorladen erfolgt verzögert. Der `redis_preload`-Scope fügt nur Metadaten zur Relation hinzu. Redis-Aufrufe werden erst beim ersten Zugriff auf ein vorgeladenes Attribut ausgeführt. Zu diesem Zeitpunkt werden alle deklarierten Attribute aller geladenen Datensätze in einem einzigen Batch abgerufen.

## Unterstützte Typen

| redis-objects Typ  | Redis-Befehl      | Vorgeladene Methoden                       |
|--------------------|-------------------|--------------------------------------------|
| `counter`          | MGET              | `value`, `nil?`                            |
| `value`            | MGET              | `value`, `nil?`                            |
| `list`             | LRANGE 0 -1       | `value`, `values`, `[]`, `length`, `empty?`|
| `set`              | SMEMBERS          | `members`, `include?`, `length`, `empty?`  |
| `sorted_set`       | ZRANGE WITHSCORES | `members`, `score`, `rank`, `length`       |
| `hash_key`         | HGETALL           | `all`, `[]`, `keys`, `values`              |

## Funktionsweise

1. `redis_preload(:attr1, :attr2)` erweitert die AR-Relation mit `RelationExtension`
2. Beim Laden der Relation wird ein `PreloadContext` an jede redis-objects-Instanz angehängt
3. Beim ersten Attributzugriff wird `PreloadContext#resolve!` ausgelöst:
   - **counter/value**-Typen: Batch-Abfrage über `MGET`
   - **list/set/sorted_set/hash_key**-Typen: Batch-Abfrage über `pipelined`
4. Jede redis-objects-Instanz erhält ihren vorgeladenen Wert über `preload!`
5. Nachfolgende Lesezugriffe geben den vorgeladenen Wert zurück, ohne Redis aufzurufen

## Anforderungen

- Ruby >= 3.1
- ActiveRecord >= 7.0
- redis-objects >= 1.7

## Lizenz

MIT-Lizenz
