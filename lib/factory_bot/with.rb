# frozen_string_literal: true

require "factory_bot"
require_relative "with/version"
require_relative "with/proxy"
require_relative "with/assoc_info"
require_relative "with/methods"

module FactoryBot
  # An intermediate state for `with` operator.
  class With
    attr_reader :factory_name, :factory_assoc_info, :withes, :args, :kwargs, :block

    def initialize(factory_name, *args, **kwargs, &block)
      @factory_name = factory_name
      @factory_assoc_info = AssocInfo.get(factory_name)
      @withes, @args = args.partition { _1.is_a? self.class }
      @kwargs = kwargs
      @block = block
    end

    # @!visibility private
    # @param build_strategy [:build, :build_stubbed, :create, :attributes_for, :with]
    # @param ancestors [Array<(AssocInfo, Object)>, nil]
    def instantiate(build_strategy, ancestors = nil)
      return self if build_strategy == :with

      kwargs = self.kwargs
      if ancestors
        kwargs = kwargs.dup
        factory_assoc_info.perform_automatic_resolution(ancestors, kwargs)
      end
      parent = FactoryBot.__send__(build_strategy, factory_name, *args, **kwargs, &block)

      ancestors = [[factory_assoc_info, parent], *ancestors || []]
      withes.each { _1.instantiate(build_strategy, ancestors) }

      parent
    end
  end
end
