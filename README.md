# Introduction

ElasticsearchRails DynamicJsonSupport - Small little change to help your model update easier in elasticsearch.

## Problem it solved

In ElasicSearch, if you define your model the following way:

    ```ruby
		# app/models/article.rb
		class Article < ActiveRecord::Base
			include Elasticsearch::Model
			include Elasticsearch::Model::Callbacks

			has_many :reviews

			def as_indexed_json options={}
				{
						id: id,
						title: title,
						article: content,
						created_at: created_at,
						updated_at: updated_at,
						reviews: reviews.map(&:as_json),
				}
			end

		# app/models/review.rb
		class Review < ActiveRecord::Base
			belongs_to :article
		end
    ```

There're 2 issues with the implementation above:

1. when the `content` is updated, this change would never be synced to the the
   `article` field in ElasticSearch, since the key is `artile` instead
2. when the corresponding review is updated, the `article` is never updated,
   since it's not awared of the change.

This library aims to solve these 2 issues, with the following convention:

- `es_json_changes(changed_attributes)` - for a given set of changed attributes,
  it would response with the update to be processed by this record
- `Elasticsearch::Model::CascadeUpdate` - class, when included, providing:
  - class methods:
    - `es_register_attributes { key => lambda }`: to register a hash of `key, 
      lambda` pairs, to be used for rendering the json. if lambda is nil,
      default to the public method of this resource named `key`.
    - `key_name, relationship_name: nil, reverse_relationship_name: nil, &blk`:
      to register an association of key, lambda. relationship_name default to
      key if not given, and reverse_relationship_name default to the singular
      form of the class name if not given. After this registration, whenever the
      corresponding resource is updated, it would trigger this resource (which
      is related to the resource) to update.

Example usage (which solves the 2 issues above) is as given below:

    ```ruby
		# app/models/article.rb
		class Article < ActiveRecord::Base
			include Elasticsearch::Model
			include Elasticsearch::Model::Callbacks
			include Elasticsearch::Model::CascadeUpdate

			has_many :reviews
			es_register_attributes id: nil, title: nil, article: lambda {|rec| rec.content }, created_at: nil, updated_at: nil
			es_register_assoc(:reviews) { |review| review.as_indexed_json }

			def elasticsearch_json_changes(changed_attributes)
				keys_to_update = changed_attributes.keys.map {|k| key_map k}
				self.as_indexed_json.select { |k,_| keys_to_update.include? k.to_s }
			end

			private
			def key_map(key)
				key = key.to_s
				case key
				when 'content'
					'article'
				else
					key
				end
			end
		end

		# app/models/review.rb
		class Review < ActiveRecord::Base
			# Make sure to register Article
			Article

			belongs_to :article

			def as_indexed_json(options = {})
				as_json
			end
		end
    ```

# More features
- Exclusion of keys: simply call 
  `record.as_indexed_json: exclude_keys: %w[keys you do not like]`.
- Selective Import: `es_to_json_when(scope_name, &condition_check_block)`. if
  the scope_name is not given, it would import all by default.
  `condition_check_block` is for checking before making the import

# ToDos

- [ ] Tests.. since I don't have time to write test case for this project yet.
- [ ] Due to the `lazy-loading` of model in rails, you need to specifically 
  specify the model in rails. Like in the `Review` class above, it's reference
  to `Article` (to make sure that `Article` class is loaded before `Review`)
- [ ] Auto generation of mapping

# Contributing to elasticsearch-rails-dynamic-json-support
 
- Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
- Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
- Fork the project.
- Start a feature/bugfix branch.
- Commit and push until you are happy with your contribution.
- Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
- Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

# Copyright

Copyright (c) 2016 Song Yangyu. See LICENSE.txt for further details.

