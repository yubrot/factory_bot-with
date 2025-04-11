# frozen_string_literal: true

RSpec.describe FactoryBot::With do
  describe "#initialize" do
    subject { described_class.new(:singular, :user, *args) }

    let(:args) { [] }

    context "with positional arguments of With instances or symbols" do
      let(:args) { [post, :hello] }
      let(:post) { described_class.new(:singular, :post) }

      it { is_expected.to have_attributes(withes: [post], traits: [:hello], attrs: {}) }
    end

    context "with positional arguments of nil or false" do
      let(:args) { [nil, false] }

      it { is_expected.to have_attributes(withes: [], traits: [], attrs: {}) }
    end

    context "with positional arguments of arrays" do
      let(:args) { [[:foo, [nil, :bar]], :baz] }

      it { is_expected.to have_attributes(withes: [], traits: %i[foo bar baz], attrs: {}) }
    end

    context "with positional arguments of hashes" do
      let(:args) { [{ x: 123, a: 1, z: 2 }, { y: 456, z: 789 }] }

      it { is_expected.to have_attributes(withes: [], traits: [], attrs: { a: 1, x: 123, y: 456, z: 789 }) }
    end
  end

  describe "#plain?" do
    subject { with.plain? }

    context "when the object has no withes, args, kwargs, and block" do
      let(:with) { described_class.new(:singular, :user) }

      it { is_expected.to be true }
    end

    context "when the object has withes, args, kwargs, or block" do
      let(:with) { described_class.new(:singular, :user, traits: [:some_trait]) }

      it { is_expected.to be false }
    end
  end

  describe "#merge" do
    subject { first.merge(second) }

    let(:first) do
      described_class.new(:singular, :user, withes: [post], traits: %i[a b], attrs: { x: 123 }) { _1 << :first }
    end
    let(:second) do
      described_class.new(:singular, :user, withes: [comment], traits: [:c], attrs: { y: 45, z: 67 }) { _1 << :second }
    end
    let(:post) { described_class.new(:singular, :post) }
    let(:comment) { described_class.new(:singular, :comment) }

    it "creates a new With instance with merged withes, args, and block" do
      expect(subject).to have_attributes(
        variation: :singular,
        factory_name: :user,
        withes: [post, comment],
        traits: %i[a b c],
        attrs: { x: 123, y: 45, z: 67 },
      )

      acc = []
      subject.block.call(acc)
      expect(acc).to eq %i[first second]
    end
  end

  describe "#instantiate" do
    it "is tested in FactoryBot::With::Methods spec"
  end

  describe ".build" do
    subject { described_class.build.user(name: "John") }

    it "creates an object with the given attributes" do
      expect(subject).to eq Test::User.new(name: "John")
    end

    # More detailed tests for factory methods are done in the FactoryBot::With::Methods spec
  end
end
