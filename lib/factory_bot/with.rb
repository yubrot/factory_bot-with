# frozen_string_literal: true

require "factory_bot"
require_relative "with/version"
require_relative "with/proxy"
require_relative "with/assoc_info"
require_relative "with/methods"

module FactoryBot
  # An intermediate state for `with` operator.
  class With
    attr_reader :variation, :factory_name, :withes, :args, :kwargs, :block

    # @!visibility private
    def initialize(variation, factory_name, *args, **kwargs, &block)
      @variation = variation
      @factory_name = factory_name
      @withes, @args = args.partition { _1.is_a? self.class }
      @kwargs = kwargs
      @block = block
    end

    # @!visibility private
    # @param build_strategy [:build, :build_stubbed, :create, :attributes_for, :with]
    # @param ancestors [Array<Array(AssocInfo, Object)>, nil]
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
          ancestors_for_child = [[assoc_info, parent], *ancestors || []]
          withes.each { _1.instantiate(build_strategy, ancestors_for_child) }
        end
      end

      result
    end
  end
end
