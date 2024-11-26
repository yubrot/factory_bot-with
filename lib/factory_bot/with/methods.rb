# frozen_string_literal: true

module FactoryBot
  class With
    # A <code>FactoryBot::Syntax::Methods</code> replacement to enable <code>factory_bot-with</code> features.
    module Methods
      include FactoryBot::Syntax::Methods

      BUILD_STRATEGY_METHODS = %i[build build_stubbed create attributes_for].freeze
      BUILD_STRATEGY_PAIR_METHODS = %i[build_pair build_stubbed_pair create_pair attributes_for_pair].freeze
      BUILD_STRATEGY_LIST_METHODS = %i[build_list build_stubbed_list create_list attributes_for_list].freeze
      METHODS = (BUILD_STRATEGY_METHODS + BUILD_STRATEGY_PAIR_METHODS + BUILD_STRATEGY_LIST_METHODS).freeze

      METHODS.each do |method_name|
        define_method(method_name) do |factory_name = nil, *args, **kwargs, &block|
          return Proxy.new(self, __method__) unless factory_name

          super(factory_name, *args, **kwargs, &block)
        end
      end
    end
  end
end
