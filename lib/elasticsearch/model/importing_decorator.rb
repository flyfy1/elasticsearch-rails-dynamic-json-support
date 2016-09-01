module Elasticsearch
  module Model
    module Importing
      module PrecheckAspect
        def import options={}, &blk
          options[:scope] = self.class_variable_get(:@@_es_scope_name) if self.class_variable_defined?(:@@_es_scope_name) && !options[:scope]
          super options, &blk
        end
      end

      module ClassMethods
        prepend PrecheckAspect
      end
    end
  end
end