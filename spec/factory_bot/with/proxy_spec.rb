# frozen_string_literal: true

RSpec.describe FactoryBot::With::Proxy do
  let(:test_class) do
    Class.new do
      def foo(name = nil, *args, **kwargs, &block)
        return FactoryBot::With::Proxy.new(self, __method__, *args, **kwargs, &block) unless name

        [name, args, kwargs, block]
      end
    end
  end

  it "forwards method calls to the receiver" do
    expect(test_class.new.foo.bar(34, abc: "def") { 345 }).to match [
      :bar,
      [34],
      { abc: "def" },
      have_attributes(call: 345),
    ]
  end
end
