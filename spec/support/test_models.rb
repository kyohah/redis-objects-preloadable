# frozen_string_literal: true

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table :widgets, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :users, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :articles, force: true do |t|
    t.integer :user_id
    t.string :title
    t.timestamps
  end
end

class User < ActiveRecord::Base
  has_many :articles
end

class Article < ActiveRecord::Base
  include Redis::Objects
  include Redis::Objects::Preloadable

  belongs_to :user

  counter :view_count
  value   :cached_summary
end

class Widget < ActiveRecord::Base
  include Redis::Objects
  include Redis::Objects::Preloadable

  counter    :view_count
  value      :last_seen
  list       :recent_ids
  set        :tag_ids
  sorted_set :ranking
  hash_key   :metadata
end
