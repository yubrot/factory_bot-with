# frozen_string_literal: true

RSpec.describe FactoryBot::With::Methods do
  # to track created objects with FactoryBot.build
  let(:objects) { [] }

  before do
    allow(FactoryBot).to receive(:build).and_wrap_original do |method, *args, **kwargs, &block|
      method.call(*args, **kwargs, &block).tap { objects << _1 }
    end
  end

  describe "#build" do
    context "when it is called with a factory name" do
      subject { build(:user, name: "John") }

      it "works the same way as FactoryBot.build" do
        expect(subject).to eq Test::User.new(name: "John")
      end
    end

    context "when it is called without a factory name" do
      subject { build.user(name: "John") }

      it "works the same way with method style syntax" do
        expect(subject).to eq Test::User.new(name: "John")
      end
    end

    context "with #with arguments" do
      subject { build.user(with.user(name: "Bob"), name: "John") }

      it "also creates child objects with same build strategy" do
        expect(subject).to eq Test::User.new(name: "John")
        expect(objects[1]).to eq Test::User.new(name: "Bob")
      end
    end

    context "with nested #with arguments" do
      subject { build.user(with.user(with.user, name: "Bob"), name: "John") }

      it "also creates child objects with same build strategy" do
        expect(subject).to eq Test::User.new(name: "John")
        expect(objects[1]).to eq Test::User.new(name: "Bob")
        expect(objects[2]).to eq Test::User.new
      end
    end

    describe "automatic association resolution" do
      subject { build.user(with.account, name: "John") }

      it "automatically adds ancestors to keyword arguments by the association information" do
        expect(subject).to eq Test::User.new(name: "John")
        expect(objects[1]).to eq Test::Account.new(user: subject)
      end

      context "when the attribute correspond to the association is explicitly specified" do
        subject { build.user(with.account(user: nil), name: "John") }

        it "does nothing about keyword arguments" do
          expect(subject).to eq Test::User.new(name: "John")
          expect(objects[1]).to eq Test::Account.new(user: nil)
        end
      end

      context "when there are multiple compatible ancestors" do
        subject { build.author(with.user(with.post, with.comment, with.account, name: "B"), name: "A") }

        it "picks a closer ancestor" do
          expect(subject).to eq Test::User.new(name: "A")
          expect(objects[1]).to eq Test::User.new(name: "B")
          expect(objects[2]).to eq Test::Post.new(author: subject)
          expect(objects[3]).to eq Test::Comment.new(commenter: Test::User.new)
          # We use `objects.last` instead of `objects[4]` here, since the behavior of `association :commenter` is
          # hidden by FactoryBot (potentially FactoryBot.build call happens)
          expect(objects.last).to eq Test::Account.new(user: objects[1])
        end
      end

      context "with factories that have multiple factory names" do
        subject { build.author(with.post(title: "Hello"), with.post(title: "World"), with.account) }

        it "respects every factory names" do
          expect(subject).to eq Test::User.new
          expect(objects[1]).to eq Test::Post.new(title: "Hello", author: subject)
          expect(objects[2]).to eq Test::Post.new(title: "World", author: subject)
          expect(objects[3]).to eq Test::Account.new(user: subject)
        end
      end

      context "when the factory name and attribute name are different" do
        subject { build.photo(with.tag, title: "P") }

        it "respects every factory names" do
          expect(subject).to eq Test::Photo.new(title: "P")
          expect(objects[1]).to eq Test::Tag.new(taggable: subject)
        end
      end
    end
  end

  describe "#with" do
    subject { with.author(:hello, with.post(:world), foo: "bar") }

    it "returns a With instance" do
      expect(subject).to have_attributes(
        factory_name: :author,
        withes: [have_attributes(factory_name: :post, args: [:world])],
        args: [:hello],
        kwargs: { foo: "bar" },
        block: nil,
      )
    end
  end
end
