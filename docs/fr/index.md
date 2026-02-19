# redis-objects-preloadable

Supprimez les appels Redis N+1 pour [redis-objects](https://github.com/nateware/redis-objects) dans les modèles ActiveRecord.

Fournit un scope `redis_preload` qui charge en lot les attributs Redis::Objects en utilisant `MGET` (pour counter/value) et des commandes `pipelined` (pour list/set/sorted_set/hash_key), suivant la même philosophie que le `preload` d'ActiveRecord.

## Installation

```ruby
gem "redis-objects-preloadable"
```

## Configuration

Incluez `Redis::Objects::Preloadable` dans votre modèle après `Redis::Objects` :

```ruby
class Pack < ApplicationRecord
  include Redis::Objects
  include Redis::Objects::Preloadable

  counter :cache_total_count, expiration: 15.minutes
  list    :recent_item_ids
  set     :tag_ids
end
```

## Utilisation

Chaînez `redis_preload` sur n'importe quelle relation ActiveRecord :

```ruby
records = Pack.order(:id)
              .redis_preload(:cache_total_count, :recent_item_ids, :tag_ids)
              .limit(100)

records.each do |pack|
  pack.cache_total_count.value   # préchargé, aucun appel Redis
  pack.recent_item_ids.values    # préchargé
  pack.tag_ids.members           # préchargé
end
```

Sans `redis_preload`, l'accès aux attributs Redis utilise des appels Redis individuels (comportement par défaut).

### Préchargement des enregistrements chargés via des associations

`redis_preload` fonctionne sur les relations de niveau supérieur. Pour les enregistrements chargés via `includes` / `preload` / `eager_load`, utilisez `Redis::Objects::Preloadable.preload` :

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
    article.view_count.value     # préchargé
    article.cached_summary.value # préchargé
  end
end
```

### Résolution paresseuse

Le préchargement est paresseux. Le scope `redis_preload` attache des métadonnées à la relation, mais aucun appel Redis n'est effectué tant que vous n'accédez pas à un attribut préchargé. À ce moment-là, tous les attributs déclarés de tous les enregistrements chargés sont récupérés en un seul lot.

## Types supportés

| Type redis-objects | Commande Redis    | Méthodes préchargées                       |
|--------------------|-------------------|--------------------------------------------|
| `counter`          | MGET              | `value`, `nil?`                            |
| `value`            | MGET              | `value`, `nil?`                            |
| `list`             | LRANGE 0 -1       | `value`, `values`, `[]`, `length`, `empty?`|
| `set`              | SMEMBERS          | `members`, `include?`, `length`, `empty?`  |
| `sorted_set`       | ZRANGE WITHSCORES | `members`, `score`, `rank`, `length`       |
| `hash_key`         | HGETALL           | `all`, `[]`, `keys`, `values`              |

## Fonctionnement

1. `redis_preload(:attr1, :attr2)` étend la relation AR avec `RelationExtension`
2. Lors du chargement de la relation, un `PreloadContext` est attaché à chaque instance redis-objects
3. Lors du premier accès à un attribut, `PreloadContext#resolve!` se déclenche :
   - Types **counter/value** : chargés en lot via `MGET`
   - Types **list/set/sorted_set/hash_key** : chargés en lot via `pipelined`
4. Chaque instance redis-objects reçoit sa valeur préchargée via `preload!`
5. Les lectures suivantes retournent la valeur préchargée sans appeler Redis

## Prérequis

- Ruby >= 3.1
- ActiveRecord >= 7.0
- redis-objects >= 1.7

## Licence

Licence MIT
