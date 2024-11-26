# frozen_string_literal: true

RSpec.describe FactoryBot::With::AssocInfo do
  describe "#perform_automatic_association_resolution and .autocomplete_fully_qualified_factory_name" do
    it "is tested in FactoryBot::With::Methods spec"
  end

  describe ".from_factory_bot_factory" do
    subject { described_class.from_factory_bot_factory(factory_name) }

    context "with unknown factory name" do
      let(:factory_name) { :unknown }

      it "raises an error" do
        expect { subject }.to raise_error ArgumentError
      end
    end

    context "with a typical factory" do
      let(:factory_name) { :post }

      it "returns an AssocInfo" do
        expect(subject).to have_attributes(
          factory_names: contain_exactly(:post),
          map: { author: :author },
        )
      end
    end

    context "with a factory including aliases" do
      let(:factory_name) { :user }

      it "considers aliases to be incompatible with each other" do
        expect(subject).to have_attributes(
          factory_names: contain_exactly(:user),
          map: {},
        )
      end
    end

    context "with an alias factory name" do
      let(:factory_name) { :author }

      it "considers that the base factory name to be compatible" do
        expect(subject).to have_attributes(factory_names: contain_exactly(:author, :user))
      end
    end

    context "with a child factory" do
      let(:factory_name) { :white }

      it "considers that the base factory name to be compatible" do
        expect(subject).to have_attributes(factory_names: contain_exactly(:color, :white))
      end
    end

    context "with a factory including multiple associations of the same factory name" do
      let(:factory_name) { :gradient }

      it "takes precedence over the first association" do
        expect(subject).to have_attributes(
          factory_names: contain_exactly(:gradient),
          map: { color: :from }, # :to is ignored
        )
      end
    end

    context "with a factory including traits" do
      let(:factory_name) { :tag }

      it "takes into account any traits" do
        expect(subject).to have_attributes(
          factory_names: contain_exactly(:tag),
          map: { video: :taggable, photo: :taggable },
        )
      end
    end
  end
end
