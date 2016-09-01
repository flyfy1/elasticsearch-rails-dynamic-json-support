module Elasticsearch
  module Model
    module Indexing
			module PrecheckAspect
        def index_document(*args)
          super if _should_pass_to_es
        end

        def delete_document(*args)
          super if _should_pass_to_es
        end

        def update_document(*args)
          super if _should_pass_to_es
        end

        def update_document_attributes(*args)
          super if _should_pass_to_es
        end

        private
        def _should_pass_to_es
          tclz = target.class
          return true unless tclz.class_variable_defined?(:@@_es_condition_block)
          condition_blk = tclz.class_variable_get(:@@_es_condition_block)
          !condition_blk || condition_blk[self]
        end
      end

      module InstanceMethods
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

        prepend PrecheckAspect
      end
    end
  end
end
