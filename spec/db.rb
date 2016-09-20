require 'active_record'
require 'elasticsearch-rails-dynamic-json-support'

ActiveRecord::Base.logger = ActiveSupport::Logger.new(STDOUT)
ActiveRecord::Base.establish_connection( adapter: 'sqlite3', database: ":memory:" )
ActiveRecord::Schema.define(version: 1) do
  create_table :articles do |t|
    t.string :title, null: false
    t.string :content, null: false
  end

  create_table :reviews do |t|
    t.integer :article_id, null: false
    t.string :content, null: false
    t.string :nonsense
  end

  add_index :reviews, :article_id
end

class Article < ActiveRecord::Base
  validates_presence_of :title
  validates_presence_of :content
end

class Review < ActiveRecord::Base
  validates_presence_of :content
end
