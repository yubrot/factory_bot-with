# frozen_string_literal: true

require "factory_bot"
require_relative "with/version"
require_relative "with/proxy"
require_relative "with/assoc_info"
require_relative "with/methods"

module FactoryBot
  # An intermediate state for <code>with</code> operator.
  class With
    # @return [:singular, :pair, :list]
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
      raise ArgumentError unless %i[singular pair list].include? variation
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
        &lambda do |first, second|
          return first unless second
          return second unless first

          lambda do |*args|
            first.call(*args)
            second.call(*args)
          end
        end.call(block, other.block)
      )
    end

    # @!visibility private
    def extend!(*args)
      args.each do |arg|
        case arg
        when self.class
          withes << arg
        when Symbol, Numeric
          traits << arg
        when Array
          extend!(*arg)
        when Hash
          attrs.merge!(arg)
        when false, nil
          # Ignored. This behavior is useful for conditional arguments like `is_premium && :premium`
        else
          raise ArgumentError, "Unsupported type for factory argument: #{arg}"
        end
      end
      self
    end

    # @!visibility private
    # @param build_strategy [Symbol]
    # @param ancestors [Array<Array(AssocInfo, Object)>, nil]
    # @return [Object]
    def instantiate(build_strategy, ancestors = nil)
      return self if build_strategy == :with

      factory_bot_method =
        variation == :singular ? build_strategy : :"#{build_strategy}_#{variation}"
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
        parents = variation == :singular ? [result] : result
        assoc_info = AssocInfo.get(factory_name)
        parents.each do |parent|
          ancestors_for_children = [[assoc_info, parent], *ancestors || []]
          withes.each { _1.instantiate(build_strategy, ancestors_for_children) }
        end
      end

      result
    end

    class << self
      # @!visibility private
      # @param variation [:singular, :pair, :list]
      # @param factory [Symbol, With]
      # @param args [Array<Object>]
      # @param kwargs [{Symbol => Object}]
      def build(variation, factory, *, **, &)
        return factory.merge(build(variation, factory.factory_name, *, **, &)) if factory.is_a? self

        new(variation, factory, &).extend!(*, { ** })
      end

      # If you want to use a custom strategy, call this along with <code>FactoryBot.register_strategy</code>.
      # @param build_strategy [Symbol]
      # @example
      #   FactoryBot.register_strategy(:json, JsonStrategy)
      #   FactoryBot::With.register_strategy(:json)
      def register_strategy(build_strategy)
        {
          singular: build_strategy,
          pair: :"#{build_strategy}_pair",
          list: :"#{build_strategy}_list",
        }.each do |variation, method_name|
          Methods.define_method(method_name) do |factory = nil, *args, **kwargs, &block|
            unless factory
              if !args.empty? || !kwargs.empty? || block
                raise ArgumentError, "#{__method__} must be called without arguments when no factory is given"
              end

              return Proxy.new(self, __method__)
            end

            With.build(variation, factory, *args, **kwargs, &block).instantiate(build_strategy)
          end
        end
      end
    end

    %i[build build_stubbed create attributes_for with].each { register_strategy _1 }
  end
end
