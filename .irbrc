# frozen_string_literal: true

require "factory_bot/with"
require_relative "spec/factories"

class << self
  prepend FactoryBot::With::Methods
end
