module Elasticsearch
  module Model
    module Indexing
      module InstanceMethods
        puts 'InstanceMethods defined.'

        def update_document options = {}
          if changed_attributes = self.instance_variable_get(:@__changed_attributes)
            attributes = if target.respond_to? :elasticsearch_json_changes
                           target.elasticsearch_json_changes changed_attributes
                         elsif respond_to?(:as_indexed_json)
                           self.as_indexed_json.select { |k,v| changed_attributes.keys.map(&:to_s).include? k.to_s }
                         else
                           changed_attributes
                         end

            update_document_attributes attributes, options
          else
            index_document(options)
          end
        end
      end
    end
  end
end
