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
    subject { build(:user, name: "John") }

    it "works the same way as FactoryBot.build" do
      expect(subject).to eq Test::User.new(name: "John")
    end

    context "when it is called without a factory name" do
      subject { build.user(name: "John") }

      it "works the same way as method-style syntax" do
        expect(subject).to eq Test::User.new(name: "John")
      end
    end

    context "with #with arguments" do
      subject { build.user(with.user(name: "Bob"), name: "John") }

      it "also creates child objects with same build strategy" do
        expect(subject).to eq objects[0]
        expect(objects).to eq [
          Test::User.new(name: "John"),
          Test::User.new(name: "Bob"),
        ]
      end
    end

    context "with nested #with arguments" do
      subject { build.user(with.user(with.user, name: "Bob"), name: "John") }

      it "also creates child objects with same build strategy" do
        expect(subject).to eq objects[0]
        expect(objects).to eq [
          Test::User.new(name: "John"),
          Test::User.new(name: "Bob"),
          Test::User.new,
        ]
      end
    end

    describe "automatic association resolution" do
      subject { build.user(with.account, name: "John") }

      it "automatically adds ancestors to keyword arguments by the association information" do
        expect(subject).to eq objects[0]
        expect(objects).to eq [
          Test::User.new(name: "John"),
          Test::Account.new(user: objects[0]),
        ]
      end

      context "when the attribute correspond to the association is explicitly specified" do
        subject { build.user(with.account(user: nil), name: "John") }

        it "does nothing about keyword arguments" do
          expect(subject).to eq objects[0]
          expect(objects).to eq [
            Test::User.new(name: "John"),
            Test::Account.new(user: nil),
          ]
        end
      end

      context "when there are multiple compatible ancestors" do
        subject { build.author(with.user(with.post, with.comment, with.account, name: "B"), name: "A") }

        it "picks a closer ancestor" do
          expect(subject).to eq objects[0]
          expect(objects[0..3]).to eq [
            Test::User.new(name: "A"),
            Test::User.new(name: "B"),
            Test::Post.new(author: objects[0]),
            Test::Comment.new(commenter: Test::User.new),
          ]
          # We use `objects.last` instead of `objects[4]` here, since the behavior of `association :commenter` is
          # hidden by FactoryBot (potentially FactoryBot.build call happens)
          expect(objects.last).to eq Test::Account.new(user: objects[1])
        end
      end

      context "with factories that have multiple factory names" do
        subject { build.author(with.post(title: "Hello"), with.post(title: "World"), with.account) }

        it "respects every factory names" do
          expect(subject).to eq objects[0]
          expect(objects).to eq [
            Test::User.new,
            Test::Post.new(title: "Hello", author: objects[0]),
            Test::Post.new(title: "World", author: objects[0]),
            Test::Account.new(user: objects[0]),
          ]
        end
      end

      context "when the factory name and attribute name are different" do
        subject { build.photo(with.tag, title: "P") }

        it "respects every factory names" do
          expect(subject).to eq objects[0]
          expect(objects).to eq [
            Test::Photo.new(title: "P"),
            Test::Tag.new(taggable: objects[0]),
          ]
        end
      end
    end

    describe "factory name completion" do
      subject { build.customer(with.profile(with.user, name: "Hello"), id: 1) }

      it "completes a factory name from ancestors" do
        expect(subject).to eq objects[0]
        expect(objects).to eq [
          Test::Customer.new(id: 1),
          Test::CustomerProfile.new(customer: objects[0], name: "Hello"),
          Test::User.new,
        ]
      end

      context "with factories that have multiple factory names" do
        subject { build.premium_customer(with.profile(name: "Hello"), id: 2) }

        it "respects every factory names" do
          expect(subject).to eq objects[0]
          expect(objects).to eq [
            Test::Customer.new(id: 2, plan: "premium"),
            Test::CustomerProfile.new(customer: objects[0], name: "Hello"),
          ]
        end
      end

      context "when there are multiple candidates for autocompletion" do
        subject { build.customer(with.information) }

        it "prefers a factory with a completed name" do
          expect(subject).to eq objects[0]
          expect(objects).to eq [
            Test::Customer.new,
            Test::CustomerInformation.new(customer: objects[0]),
          ]
        end
      end
    end

    describe "passing a block to factory methods" do
      subject do
        build.customer(id: 1) { build.profile(name: "Kog") }
        # or as usual FactoryBot
        build.customer(id: 2) { |c| build.customer_profile(name: "Kei", customer: c) }
      end

      it "creates a scope for association resolution and calls the block with created objects" do
        subject
        expect(objects).to eq [
          Test::Customer.new(id: 1),
          Test::CustomerProfile.new(customer: objects[0], name: "Kog"),
          Test::Customer.new(id: 2),
          Test::CustomerProfile.new(customer: objects[2], name: "Kei"),
        ]
      end

      context "when passing a block to list factory methods" do
        subject { build_list.node(3) { build.node } }

        # This is an incompatible behavior with FactoryBot. See lib/factory_bot/with.rb#L121
        it "calls the block for each created object" do
          base = subject[0].index
          expect(objects).to eq [
            Test::Node.new(index: base),
            Test::Node.new(index: base + 1),
            Test::Node.new(index: base + 2),
            Test::Node.new(index: base + 3, parent: objects[0]),
            Test::Node.new(index: base + 4, parent: objects[1]),
            Test::Node.new(index: base + 5, parent: objects[2]),
          ]
        end
      end
    end

    describe "use #with as a template" do
      subject { build(record_template, title: "Overriden title") }

      let(:record_template) { with.record(:example) }

      it "creates an object after composing args and kwargs" do
        expect(subject).to eq Test::Record.new(name: "Example", title: "Overriden title")
      end

      context "when the factory method is called without additional optional arguments" do
        subject { build(record_template) }

        before { allow(FactoryBot::With).to receive(:new).and_call_original }

        it "does not create a new With instance when merging" do
          subject
          expect(FactoryBot::With).to have_received(:new).twice # one for record_template, one for build
        end
      end
    end
  end

  describe "#build_pair" do
    subject { build_pair.node }

    it "creates 2 objects" do
      expect(subject).to eq [objects[0], objects[1]]
      base = subject[0].index
      expect(objects).to eq [
        Test::Node.new(index: base),
        Test::Node.new(index: base + 1),
      ]
    end

    context "when each element has a single object" do
      subject { build_pair.node(with.node) }

      it "creates 2 + (2x 1) objects" do
        expect(subject).to eq [objects[0], objects[1]]
        base = subject[0].index
        expect(objects).to eq [
          Test::Node.new(index: base),
          Test::Node.new(index: base + 1),
          Test::Node.new(index: base + 2, parent: objects[0]),
          Test::Node.new(index: base + 3, parent: objects[1]),
        ]
      end
    end

    context "when each element has a pair of objects" do
      subject { build_pair.node(with_pair.node) }

      it "creates 2 + (2x 2) objects" do
        expect(subject).to eq [objects[0], objects[1]]
        base = subject[0].index
        expect(objects).to eq [
          Test::Node.new(index: base),
          Test::Node.new(index: base + 1),
          Test::Node.new(index: base + 2, parent: objects[0]),
          Test::Node.new(index: base + 3, parent: objects[0]),
          Test::Node.new(index: base + 4, parent: objects[1]),
          Test::Node.new(index: base + 5, parent: objects[1]),
        ]
      end
    end

    context "when a object has a pair of objects" do
      subject { build.node(with_pair.node) }

      it "creates 1 + (1x 2) objects" do
        expect(subject).to eq objects[0]
        base = subject.index
        expect(objects).to eq [
          Test::Node.new(index: base),
          Test::Node.new(index: base + 1, parent: objects[0]),
          Test::Node.new(index: base + 2, parent: objects[0]),
        ]
      end
    end
  end

  describe "#build_list" do
    subject { build_list.node(3) }

    it "creates 3 objects" do
      expect(subject).to eq [objects[0], objects[1], objects[2]]
      base = subject[0].index
      expect(objects).to eq [
        Test::Node.new(index: base),
        Test::Node.new(index: base + 1),
        Test::Node.new(index: base + 2),
      ]
    end

    context "when each element has a single object" do
      subject { build_list.node(3, with.node) }

      it "creates 3 + (3x 1) objects" do
        expect(subject).to eq [objects[0], objects[1], objects[2]]
        base = subject[0].index
        expect(objects).to eq [
          Test::Node.new(index: base),
          Test::Node.new(index: base + 1),
          Test::Node.new(index: base + 2),
          Test::Node.new(index: base + 3, parent: objects[0]),
          Test::Node.new(index: base + 4, parent: objects[1]),
          Test::Node.new(index: base + 5, parent: objects[2]),
        ]
      end
    end

    context "when each element has a pair of objects" do
      subject { build_list.node(3, with_pair.node) }

      it "creates 3 + (3x 2) objects" do
        expect(subject).to eq [objects[0], objects[1], objects[2]]
        base = subject[0].index
        expect(objects).to eq [
          Test::Node.new(index: base),
          Test::Node.new(index: base + 1),
          Test::Node.new(index: base + 2),
          Test::Node.new(index: base + 3, parent: objects[0]),
          Test::Node.new(index: base + 4, parent: objects[0]),
          Test::Node.new(index: base + 5, parent: objects[1]),
          Test::Node.new(index: base + 6, parent: objects[1]),
          Test::Node.new(index: base + 7, parent: objects[2]),
          Test::Node.new(index: base + 8, parent: objects[2]),
        ]
      end
    end

    context "when a object has a list of objects" do
      subject { build.node(with_list.node(4)) }

      it "creates 1 + (1x 4) objects" do
        expect(subject).to eq objects[0]
        base = subject.index
        expect(objects).to eq [
          Test::Node.new(index: base),
          Test::Node.new(index: base + 1, parent: objects[0]),
          Test::Node.new(index: base + 2, parent: objects[0]),
          Test::Node.new(index: base + 3, parent: objects[0]),
          Test::Node.new(index: base + 4, parent: objects[0]),
        ]
      end
    end

    context "with nested list" do
      subject { build_list.node(2, with_list.node(2, with_list.node(2))) }

      it "creates 2 + (2x 2) + (2x 2x 2) objects" do
        expect(subject).to eq [objects[0], objects[1]]
        base = subject[0].index
        expect(objects).to eq [
          Test::Node.new(index: base),
          Test::Node.new(index: base + 1),
          Test::Node.new(index: base + 2, parent: objects[0]),
          Test::Node.new(index: base + 3, parent: objects[0]),
          Test::Node.new(index: base + 4, parent: objects[2]),
          Test::Node.new(index: base + 5, parent: objects[2]),
          Test::Node.new(index: base + 6, parent: objects[3]),
          Test::Node.new(index: base + 7, parent: objects[3]),
          Test::Node.new(index: base + 8, parent: objects[1]),
          Test::Node.new(index: base + 9, parent: objects[1]),
          Test::Node.new(index: base + 10, parent: objects[8]),
          Test::Node.new(index: base + 11, parent: objects[8]),
          Test::Node.new(index: base + 12, parent: objects[9]),
          Test::Node.new(index: base + 13, parent: objects[9]),
        ]
      end
    end
  end

  describe "#create, #create_pair, and #create_list" do
    subject { create.record }

    it "creates objects with create build strategy" do
      expect(subject).to eq Test::Record.new(name: "Record", title: "Title", created_at: "2024-01-01")
    end
  end

  describe "#attributes_for, #attributes_for_pair, and #attributes_for_list" do
    subject { attributes_for.record }

    it "creates objects with attributes_for build strategy" do
      expect(subject).to eq(name: "Record", title: "Title")
    end
  end

  describe "#build_stubbed, #build_stubbed_pair, and #build_stubbed_list" do
    it "is almost similar to #build series, although the build strategy is different"
  end

  describe "#with" do
    subject { with.author(:hello, with.post(:world), foo: "bar") }

    it "returns a With instance" do
      expect(subject).to have_attributes(
        variation: :singular,
        factory_name: :author,
        withes: [have_attributes(factory_name: :post, traits: [:world])],
        traits: [:hello],
        attrs: { foo: "bar" },
        block: nil,
      )
    end

    context "without factory name" do
      subject { with(user:) { build.account } }

      let(:user) { build.user(name: "John") }

      it "works as association resolution candidates" do
        account = Test::Account.new(user:)
        expect(subject).to eq account
        expect(objects).to eq [user, account]
      end

      context "with complex control-flow with Fibers" do
        subject do
          customers = [
            build.customer(id: 1),
            build.customer(id: 2),
          ]
          f = Fiber.new do
            with(customer: customers[0]) do
              build.profile(name: "A")
              Fiber.yield
              build.profile(name: "B")
            end
          end
          with(customer: customers[1]) do
            build.profile(name: "C")
            f.resume
            build.profile(name: "D")
          end
          f.resume
        end

        it "keeps lexical scope" do
          subject
          expect(objects).to eq [
            Test::Customer.new(id: 1),
            Test::Customer.new(id: 2),
            Test::CustomerProfile.new(customer: objects[1], name: "C"),
            Test::CustomerProfile.new(customer: objects[0], name: "A"),
            Test::CustomerProfile.new(customer: objects[1], name: "D"),
            Test::CustomerProfile.new(customer: objects[0], name: "B"),
          ]
        end
      end

      context "with a block that takes positional arguments" do
        subject do
          with(user:, node:) do |user, node| # keeps order of arguments
            build.node(parent: user, index: 1)
            build.node(parent: node, index: 2)
          end
        end

        let(:node) { build.node(parent: nil, index: 0) }

        it "takes created objects as positional arguments" do
          subject
          expect(objects).to eq [
            user,
            node,
            Test::Node.new(parent: user, index: 1),
            Test::Node.new(parent: node, index: 2),
          ]
        end
      end

      context "with a block that takes keyword arguments" do
        subject do
          with(user:) do |user:|
            build.node(parent: user, index: 1)
          end
        end

        it "takes created objects as keyword arguments" do
          subject
          expect(objects).to eq [
            user,
            Test::Node.new(parent: user, index: 1),
          ]
        end
      end
    end
  end

  describe "#with_list" do
    subject { with_list.author(3, :hello, with.post(:world), foo: "bar") }

    it "returns a With instance" do
      expect(subject).to have_attributes(
        variation: :list,
        factory_name: :author,
        withes: [have_attributes(factory_name: :post, traits: [:world])],
        traits: [3, :hello], # factory_bot-with interprets numeric arguments as traits
        attrs: { foo: "bar" },
        block: nil,
      )
    end

    context "without factory name" do
      subject { with_list(rank:, color:) { build.card } }

      let(:rank) { [build.rank(name: "ace"), build.rank(name: "king")] }
      let(:color) { [build.color(code: "red"), build.color(code: "blue")] }

      it "works as association resolution candidates" do
        cards = [
          Test::Card.new(rank: rank[0], color: color[0]),
          Test::Card.new(rank: rank[0], color: color[1]),
          Test::Card.new(rank: rank[1], color: color[0]),
          Test::Card.new(rank: rank[1], color: color[1]),
        ]
        expect(subject).to eq cards
        expect(objects).to eq [*rank, *color, *cards]
      end
    end
  end
end
