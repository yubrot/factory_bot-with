# frozen_string_literal: true

module FactoryBot
  class With
    # An association information of a FactoryBot factory.
    class AssocInfo
      # @return [Set<Symbol>] List of factory names to be considered compatible with this factory
      attr_reader :factory_names
      # @return [{Symbol => Symbol}] a map from factory names to association names
      attr_reader :map

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

      # @param ancestors [Array<(AssocInfo, Object)>]
      # @param dest [{Symbol => Object}]
      def perform_automatic_resolution(ancestors, dest)
        priorities = {}
        map.each do |factory_name, attribute|
          # skip if this attribute is explicitly specified
          next if dest.member?(attribute) && !priorities.member?(attribute)

          # closer ancestors have higher (lower integer) priority
          ancestor, priority = ancestors.each_with_index.find do |ancestor, _|
            ancestor[0].factory_names.include?(factory_name)
          end
          next if !ancestor || priorities.fetch(attribute, Float::INFINITY) <= priority

          priorities[attribute] = priority
          dest[attribute] = ancestor[1]
        end
      end

      class << self
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
