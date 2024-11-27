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
    # @return [Array<Object>]
    attr_reader :args
    # @return [{Symbol => Object}]
    attr_reader :kwargs
    # @return [Proc, nil]
    attr_reader :block

    # @!visibility private
    def initialize(variation, factory_name, *args, **kwargs, &block)
      @variation = variation
      @factory_name = factory_name
      @withes, @args = args.partition { _1.is_a? self.class }
      @kwargs = kwargs
      @block = block
    end

    # @!visibility private
    # @return [Boolean]
    def plain? = withes.empty? && args.empty? && kwargs.empty? && block.nil?

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
        *args, *other.args, *withes, *other.withes,
        **kwargs, **other.kwargs,
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
      factory_name, kwargs =
        if ancestors
          kwargs = @kwargs.dup
          factory_name = AssocInfo.autocomplete_fully_qualified_factory_name(ancestors, @factory_name)
          AssocInfo.get(factory_name).perform_automatic_association_resolution(ancestors, kwargs)
          [factory_name, kwargs]
        else
          [@factory_name, @kwargs]
        end
      result = FactoryBot.__send__(factory_bot_method, factory_name, *args, **kwargs, &block)

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

    # @!visibility private
    # @param first [Proc, nil]
    # @param second [Proc, nil]
    # @return [Proc, nil]
    def self.merge_block(first, second)
      return first unless second
      return second unless first

      lambda do |*args|
        first.call(*args)
        second.call(*args)
      end
    end
  end
end
