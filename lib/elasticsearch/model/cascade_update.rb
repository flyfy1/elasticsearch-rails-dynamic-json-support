module Elasticsearch
  module Model
    module CascadeUpdate

      # Only for internal use. Holds the mapping from relationship, to the corresponding json
      class Actor
        def initialize(relationship_name, singularity, resource_to_json)
          @relationship_name = relationship_name
          @singularity = singularity.to_sym
          @resource_to_json = resource_to_json
        end

        def to_json(record)
          resource = record.public_send @relationship_name
          if(@singularity == :plural)
            resource.map {|record| @resource_to_json[record] }
          else  # treat it as singular otherwise
            @resource_to_json[resource]
          end
        end
      end

      extend ActiveSupport::Concern

      # update, just for a specific key, or set of keys
      def es_partial_update(*keys)
        keys = keys.map(&:to_s)

        res_json = {}
        keys.each do |key|
          res_json[key] = self.class.es_register_assoc(key).to_json(self)
        end

        self.__elasticsearch__.update_document_attributes res_json
      end

      def as_indexed_json(options = {})
        self.class.to_indexed_json(self, options)
      end

      class_methods do

        # attributes is a pair of <key, block>
        def es_register_attrs *attributes
          hashed_attributes = attributes.extract_options!

          attributes.each do |k|
            json_attribute_registry[k] = lambda { |record| record.public_send k }
          end

          hashed_attributes.each do |k, v|
            k = k.to_s
            json_attribute_registry[k] = v || lambda { |record| record.public_send k }
          end
        end

        # default `reverse_relationship_name` to be singular case if not given
        def es_register_assoc key_name, relationship_name: nil, reverse_relationship_name: nil, &blk
          key_name = key_name.to_s
          return json_relationship_registry[key_name] unless blk

          # If key_name has been defined, then fail fast
          fail "json key_name has been already defined: #{key_name} for class #{self.name}" if json_relationship_registry[key_name]

          relationship_name = key_name unless relationship_name
          relationship_name = relationship_name.to_s

          reverse_relationship_name = self.name.demodulize.downcase unless reverse_relationship_name
          reverse_relationship_name = reverse_relationship_name.to_s

          reflection = reflect_on_association relationship_name

          reflected_class = reflection.class_name.constantize

          actor = Actor.new relationship_name, get_singularity(reflection), blk
          json_relationship_registry[key_name] = actor

          reflected_class.class_eval do
            after_commit do
              Array.wrap(self.public_send reverse_relationship_name).each do |record|
                record.es_partial_update(key_name)
              end
            end
          end
        end

        def to_indexed_json(record, options = {})
          result = {}
          exclude_keys = options[:exclude_keys]
          exclude_keys = [] unless exclude_keys
          exclude_keys = exclude_keys.map(&:to_s)

          json_attribute_registry.each do |k, blk|
            k = k.to_s
            next if exclude_keys.include? k
            result[k] = blk[record]
          end

          json_relationship_registry.each do |k, actor|
            k = k.to_s
            next if exclude_keys.include? k
            result[k] = actor.to_json(record)
          end

          result
        end

        private
        def json_relationship_registry
          @@__json_actor_registry_ ||= {}
        end

        def json_attribute_registry
          @@__json_attribute_registry ||= {}
        end

        def get_singularity(reflection)
          case reflection
            when ActiveRecord::Reflection::HasManyReflection, ActiveRecord::Reflection::ThroughReflection,
                ActiveRecord::Reflection::HasAndBelongsToManyReflection
            :plural
          else
            :singular
          end
        end
      end
    end
  end
end