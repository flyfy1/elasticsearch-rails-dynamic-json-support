module Elasticsearch
  module Model
    module CascadeUpdate
      extend ActiveSupport::Concern

      # update, just for a specific key, or set of keys
      def es_partial_update(*keys)
        keys = keys.map(&:to_s)

        res_json = {}
        keys.each do |key|
          res_json[key] = self.class.es_get_actor(key)[self]
        end

        self.__elasticsearch__.update_document_attributes res_json
      end

      def as_indexed_json(options = {})
        self.class.to_indexed_json(self, options)
      end

      class_methods do
        def es_to_json_when(scope_name, &condition_block)
          instance_variable_set(:@_es_condition_block, condition_block)
          instance_variable_set(:@_es_scope_name, scope_name)
        end

        def es_register_silent_attrs *attributes
          __es_register_attrs __silent_attribute_registry, attributes
        end

        def es_get_actor(key, include_silent: true)
          if include_silent
            __load_attribute_registry[key] || __silent_attribute_registry[key]
          else
            __silent_attribute_registry[key]
          end
        end

        # attributes is a pair of <key, block>
        def es_register_attrs *attributes
          __es_register_attrs __load_attribute_registry, attributes
        end

        # register association, with: 
        #   - key_name = the key name of the json object
        #   - relationship: can be nil, String or a Proc.
        #       - if nil or string, then default to the key_name. In that case, 
        #         the listening_class can be guessed intelligently if not given
        #       - if lambda, then this is used to fetch the relationship
        #   - listening_class: default to guess from the relationship, to set the
        #                   listener upon
        #   - reverse_trigger: lambda {|obj, changes| do_things }
        #         the reverse_trigger, when the model change, to render the json
        #         document and update the objects. the returns is an array of the
        #         original object to be updated
        #   - slient: default to false. If silent, then it's not exported by
        #             default
        #   - &blk: the render_assoc, default to be: `object#as_indexed_json`. 
        #         it would use a `map` by default for the has_many relationships
        def es_register_assoc key_name, relationship: nil, reverse_relationship: nil,
                              listening_class: nil, reverse_trigger: nil, 
                              silent: false, &blk
          key_name = key_name.to_s
          relationship ||= key_name 

          relationship_getter = case relationship
                                when String, Symbol
                                  lambda {|obj| obj.public_send relationship}
                                when Proc
                                  relationship
                                else
                                  fail "relationsihp can only be empty, String, or Proc, #{relationsihp} given."
                                end

          single_to_json = blk || lambda do |r|
            r.respond_to?(:as_indexed_json) ?  r.as_indexed_json : r.as_json
          end

          resource_to_json = lambda do |resource| 
            resource.respond_to?(:map) ? resource.map(&single_to_json) : single_to_json[resource]
          end

          (silent ? __silent_attribute_registry : __load_attribute_registry )[key_name] = lambda do |record|
            resource = relationship_getter[record]
            resource_to_json[resource]
          end

          reflection = nil
          unless listening_class
            # try to guess reverse class if not given
            reflection = reflect_on_association relationship
            listening_class = reflection.class_name.constantize
          end

          reverse_relationship = self.name.demodulize.downcase unless reverse_relationship

          listening_class.class_eval do
            # include Elasticsearch::Model unless include? Elasticsearch::Model
            before_save do |instance|
              self.instance_variable_set(:@__changed_attributes__, instance.changes)
            end

            after_commit do |instance|
              changes = instance.instance_variable_get(:@__changed_attributes__)

              Array.wrap(self.public_send reverse_relationship).each do |record|
                record.es_partial_update(key_name) 
              end if !reverse_trigger || reverse_trigger[instance, changes]

              instance.remove_instance_variable(:@__changed_attributes__)
            end
          end
        end

        def to_indexed_json(record, options = {})
          result = {}
          exclude_keys = (options[:exclude] || []).map(&:to_s)
          include_keys = (options[:include] || []).map(&:to_s)

          __load_attribute_registry.each do |k, blk|
            next if exclude_keys.include? k
            result[k] = blk[record]
          end

          __silent_attribute_registry.each do |k, blk|
            next unless include_keys.include? k
            result[k] = blk[record]
          end

          result
        end

        private
        def __load_attribute_registry
          instance_variable_set :@__json_attribute_registry, {} unless instance_variable_defined? :@__json_attribute_registry
          instance_variable_get :@__json_attribute_registry
        end
        def __silent_attribute_registry
          instance_variable_set :@__json_silent_attr_registry, {} unless instance_variable_defined? :@__json_silent_attr_registry
          instance_variable_get :@__json_silent_attr_registry
        end

        # attributes is a pair of <key, block>
        def __es_register_attrs register_hash, attributes
          hashed_attributes = attributes.extract_options!

          attributes.each do |k|
            register_hash[k.to_s] = lambda { |record| record.public_send k }
          end

          hashed_attributes.each do |k, v|
            register_hash[k.to_s] = v || lambda { |record| record.public_send k }
          end
        end
      end
    end
  end
end
