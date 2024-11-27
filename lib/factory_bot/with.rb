# frozen_string_literal: true

require "factory_bot"
require_relative "with/version"
require_relative "with/proxy"
require_relative "with/assoc_info"
require_relative "with/methods"

module FactoryBot
  # An intermediate state for <code>with</code> operator.
  class With
    # @return [:unit, :pair, :list]
    attr_reader :variation
    # @return [Symbol]
    attr_reader :factory_name
    # @return [Array<With>]
    attr_reader :withes
    # @return [Array<Numeric, Symbol>] Numeric is also treated as a trait for convenience
    attr_reader :traits
    # @return [{Symbol => Object}]
    attr_reader :attrs
    # @return [Proc, nil]
    attr_reader :block

    # @!visibility private
    def initialize(variation, factory_name, withes: [], traits: [], attrs: {}, &block)
      raise ArgumentError unless %i[unit pair list].include? variation
      raise TypeError unless factory_name.is_a? Symbol
      raise TypeError unless withes.is_a?(Array) && withes.all? { _1.is_a? self.class }
      raise TypeError unless traits.is_a?(Array) && traits.all? { _1.is_a?(Symbol) || _1.is_a?(Numeric) }
      raise TypeError unless attrs.is_a?(Hash) && attrs.keys.all? { _1.is_a? Symbol }

      @variation = variation
      @factory_name = factory_name
      @withes = withes
      @traits = traits
      @attrs = attrs
      @block = block
    end

    # @!visibility private
    # @return [Boolean]
    def plain? = withes.empty? && traits.empty? && attrs.empty? && block.nil?

    # @!visibility private
    # @param other [With]
    # @return [With]
    def merge(other)
      raise TypeError, "oter must be an instance of #{self.class}" unless other.is_a? self.class
      raise ArgumentError, "other must have the same variation" if other.variation != variation
      raise ArgumentError, "other must have the same factory_name" if other.factory_name != factory_name

      return self if other.plain?
      return other if plain?

      self.class.new(
        variation,
        factory_name,
        withes: [*withes, *other.withes],
        traits: [*traits, *other.traits],
        attrs: { **attrs, **other.attrs },
        &self.class.merge_block(block, other.block)
      )
    end

    # @!visibility private
    # @param build_strategy [:build, :build_stubbed, :create, :attributes_for, :with]
    # @param ancestors [Array<Array(AssocInfo, Object)>, nil]
    # @return [Object]
    def instantiate(build_strategy, ancestors = nil)
      return self if build_strategy == :with

      factory_bot_method = Methods::VARIATIONS[variation][build_strategy]
      factory_name, attrs =
        if ancestors
          attrs = @attrs.dup
          factory_name = AssocInfo.autocomplete_fully_qualified_factory_name(ancestors, @factory_name)
          AssocInfo.get(factory_name).perform_automatic_association_resolution(ancestors, attrs)
          [factory_name, attrs]
        else
          [@factory_name, @attrs]
        end
      result = FactoryBot.__send__(factory_bot_method, factory_name, *traits, **attrs, &block)

      unless withes.empty?
        parents = variation == :unit ? [result] : result
        assoc_info = AssocInfo.get(@factory_name)
        parents.each do |parent|
          ancestors_for_children = [[assoc_info, parent], *ancestors || []]
          withes.each { _1.instantiate(build_strategy, ancestors_for_children) }
        end
      end

      result
    end

    class << self
      # @!visibility private
      # @param variation [:unit, :pair, :list]
      # @param factory [Symbol, With]
      # @param args [Array<Object>]
      # @param kwargs [{Symbol => Object}]
      def build(variation, factory, *, **, &)
        return factory.merge(build(variation, factory.factory_name, *, **, &)) if factory.is_a? self

        with = new(variation, factory, &)
        insert_args!(with, *)
        with.attrs.merge!(**)
        with
      end

      def insert_args!(with, *args)
        args.each do |arg|
          case arg
          when self
            with.withes << arg
          when Symbol, Numeric
            with.traits << arg
          when Array
            insert_args!(with, *arg)
          when Hash
            with.attrs.merge!(arg)
          when false, nil
            # Ignored. This behavior is useful for conditional arguments like `is_premium && :premium`
          else
            raise ArgumentError, "Unsupported type for factory argument: #{arg}"
          end
        end
      end

      # @!visibility private
      # @param first [Proc, nil]
      # @param second [Proc, nil]
      # @return [Proc, nil]
      def merge_block(first, second)
        return first unless second
        return second unless first

        lambda do |*args|
          first.call(*args)
          second.call(*args)
        end
      end
    end
  end
end
