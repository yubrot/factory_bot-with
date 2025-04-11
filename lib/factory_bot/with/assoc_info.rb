# frozen_string_literal: true

module FactoryBot
  class With
    # An association information of a FactoryBot factory.
    class AssocInfo
      # @return [Set<Symbol>] List of factory names to be considered compatible with this factory
      attr_reader :factory_names
      # @return [{Symbol => Symbol}] a map from factory names to association names
      attr_reader :map

      # @!visibility private
      def initialize(factory_names, map)
        unless factory_names.is_a?(Set) && factory_names.all? { _1.is_a?(Symbol) }
          raise ArgumentError, "factory_names must be a Set of Symbols"
        end
        unless map.is_a?(Hash) && map.all? { _1.is_a?(Symbol) && _2.is_a?(Symbol) }
          raise ArgumentError, "map must be a Hash of Symbol"
        end

        @factory_names = factory_names
        @map = map
      end

      # @param ancestors [Array<Array(AssocInfo, Object)>]
      # @param dest [{Symbol => Object}]
      def perform_automatic_association_resolution(ancestors, dest)
        priorities = {}
        map.each do |factory_name, attribute|
          # skip if this attribute is explicitly specified
          next if dest.member?(attribute) && !priorities.member?(attribute)

          # closer ancestors have higher (lower integer) priority
          ancestor, priority = ancestors.each_with_index.find do |(ancestor_assoc_info, _), _|
            ancestor_assoc_info.factory_names.include?(factory_name)
          end
          next if !ancestor || priorities.fetch(attribute, Float::INFINITY) <= priority

          priorities[attribute] = priority
          dest[attribute] = ancestor[1]
        end
      end

      class << self
        # @param ancestors [Array<Array(AssocInfo, Object)>]
        # @param partial_factory_name [Symbol]
        # @return [Symbol]
        def perform_factory_name_completion(ancestors, partial_factory_name)
          ancestors.each do |(ancestor_assoc_info, _)|
            ancestor_assoc_info.factory_names.each do |ancestor_factory_name|
              factory_name = :"#{ancestor_factory_name}_#{partial_factory_name}"
              return factory_name if exists?(factory_name)
            end
          end

          # Attempt to resolve with the completed names, then attempt to resolve with the original name.
          # If we want to avoid completion, we should be able to simply use a factory such as build or create.
          return partial_factory_name if exists?(partial_factory_name)

          raise ArgumentError, "FactoryBot factory #{partial_factory_name} is not defined"
        end

        # @param factory_name [Symbol]
        # @return [Boolean]
        def exists?(factory_name)
          !!cache.fetch(factory_name) { FactoryBot.factories.registered?(factory_name) }
        end

        # @param factory_name [Symbol]
        # @return [AssocInfo]
        def get(factory_name)
          cache.fetch(factory_name) { cache[factory_name] = from_factory_bot_factory(factory_name) }
        end

        # @param factory_name [Symbol]
        # @return [AssocInfo]
        def from_factory_bot_factory(factory_name)
          unless FactoryBot.factories.registered?(factory_name)
            raise ArgumentError, "FactoryBot factory #{factory_name} is not defined"
          end

          factory = FactoryBot.factories.find(factory_name)

          # NOTE: We consider aliases to be incompatible with each other
          factory_names = Set[factory_name]
          map = {}
          while factory.is_a?(FactoryBot::Factory)
            factory_names << factory.name
            # Here, we use reverse_each to prioritize the upper association
            factory.with_traits(factory.defined_traits.map(&:name)).associations.reverse_each do |assoc|
              map[Array(assoc.factory)[0].to_sym] = assoc.name
            end

            factory = factory.__send__(:parent)
          end

          new(factory_names, map)
        end

        # @return [{Symbol => AssocInfo}]
        def cache = @cache ||= {}
      end
    end
  end
end
