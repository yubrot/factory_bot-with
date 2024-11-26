# frozen_string_literal: true

RSpec.describe FactoryBot::With do
  describe "#plain?" do
    subject { with.plain? }

    context "when the object has no withes, args, kwargs, and block" do
      let(:with) { described_class.new(:unit, :user) }

      it { is_expected.to be true }
    end

    context "when the object has withes, args, kwargs, or block" do
      let(:with) { described_class.new(:unit, :user, :some_trait) }

      it { is_expected.to be false }
    end
  end

  describe "#merge" do
    subject { first.merge(second) }

    let(:first) { described_class.new(:unit, :user, post, :a, :b, x: 123) { _1 << :first } }
    let(:second) { described_class.new(:unit, :user, comment, :c, y: 45, z: 67) { _1 << :second } }
    let(:post) { described_class.new(:unit, :post) }
    let(:comment) { described_class.new(:unit, :comment) }

    it "creates a new With instance with merged withes, args, and block" do
      expect(subject).to have_attributes(
        variation: :unit,
        factory_name: :user,
        withes: [post, comment],
        args: %i[a b c],
        kwargs: { x: 123, y: 45, z: 67 },
      )

      acc = []
      subject.block.call(acc)
      expect(acc).to eq %i[first second]
    end
  end

  describe "#instantiate" do
    it "is tested in FactoryBot::With::Methods spec"
  end
end
