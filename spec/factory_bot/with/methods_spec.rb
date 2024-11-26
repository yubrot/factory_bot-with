# frozen_string_literal: true

RSpec.describe FactoryBot::With::Methods do
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
  end
end
