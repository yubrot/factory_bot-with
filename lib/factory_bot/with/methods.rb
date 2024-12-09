# frozen_string_literal: true

module FactoryBot
  class With
    # A <code>FactoryBot::Syntax::Methods</code> replacement to enable <code>factory_bot-with</code> features.
    module Methods
      include FactoryBot::Syntax::Methods
    end
  end
end
