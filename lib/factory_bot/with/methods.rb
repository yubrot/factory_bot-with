# frozen_string_literal: true

module FactoryBot
  class With
    # A <code>FactoryBot::Syntax::Methods</code> replacement to enable <code>factory_bot-with</code> features.
    module Methods
      include FactoryBot::Syntax::Methods

      BUILD_STRATEGIES = %i[build build_stubbed create attributes_for with].freeze
      VARIATIONS = {
        unit: BUILD_STRATEGIES.to_h { [_1, _1] }.freeze,
        pair: BUILD_STRATEGIES.to_h { [_1, :"#{_1}_pair"] }.freeze,
        list: BUILD_STRATEGIES.to_h { [_1, :"#{_1}_list"] }.freeze,
      }.freeze

      VARIATIONS.each do |variation, build_strategies|
        build_strategies.each do |build_strategy, method_name|
          define_method(method_name) do |factory = nil, *args, **kwargs, &block|
            return Proxy.new(self, __method__) unless factory

            With.build(variation, factory, *args, **kwargs, &block).instantiate(build_strategy)
          end
        end
      end
    end
  end
end
