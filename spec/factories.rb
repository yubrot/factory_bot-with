# frozen_string_literal: true

# This module contains data types and factories for testing this gem.
module Test
  # TESTING aliases
  User = Struct.new(:name, keyword_init: true)
  Post = Struct.new(:title, :author, keyword_init: true)
  Comment = Struct.new(:text, :commenter, keyword_init: true)
  Account = Struct.new(:user, keyword_init: true)

  FactoryBot.define do
    factory(:user, class: "Test::User", aliases: %i[author commenter])
    factory(:post, class: "Test::Post") { author }
    factory(:comment, class: "Test::Comment") { commenter }
    factory(:account, class: "Test::Account") { user }
  end

  # TESTING parent
  Color = Struct.new(:code, keyword_init: true)
  Gradient = Struct.new(:from, :to, keyword_init: true)

  FactoryBot.define do
    factory(:color, class: "Test::Color") do
      factory(:white) { code { "white" } }
    end
    factory(:gradient, class: "Test::Gradient") do
      from factory: :color
      to factory: :color # TESTING same type
    end
  end

  # TESTING completion
  Customer = Struct.new(:id, :plan, keyword_init: true)
  CustomerProfile = Struct.new(:name, :customer, keyword_init: true)
  CustomerInformation = Struct.new(:customer, keyword_init: true)
  Information = Struct.new(:title, keyword_init: true)

  FactoryBot.define do
    factory(:customer, class: "Test::Customer") do
      factory(:premium_customer) { plan { "premium" } }
    end
    factory(:customer_profile, class: "Test::CustomerProfile") { customer }
    factory(:customer_information, class: "Test::CustomerInformation") { customer }
    factory(:information, class: "Test::Information")
  end

  # TESTING traits
  Video = Struct.new(:title, keyword_init: true)
  Photo = Struct.new(:title, keyword_init: true)
  Tag = Struct.new(:taggable, keyword_init: true)

  FactoryBot.define do
    factory(:video, class: "Test::Video")
    factory(:photo, class: "Test::Photo")
    factory(:tag, class: "Test::Tag") do
      trait :for_video do
        taggable factory: :video
      end

      trait :for_photo do
        taggable factory: :photo # TESTING same attribute
      end
    end
  end

  # TESTING recursive data structure
  Node = Struct.new(:parent, :index, keyword_init: true)

  FactoryBot.define do
    factory(:node, class: "Test::Node") do
      sequence(:index)

      trait :non_root do
        parent factory: :node
      end
    end
  end

  # TESTING multiple associations
  Rank = Struct.new(:name, keyword_init: true)
  Card = Struct.new(:rank, :color, keyword_init: true)

  FactoryBot.define do
    factory(:rank, class: "Test::Rank")
    factory(:card, class: "Test::Card") do
      rank
      color
    end
  end

  # TESTING create and attributes_for
  Record = Struct.new(:name, :title, :created_at, keyword_init: true)

  FactoryBot.define do
    factory(:record, class: "Test::Record") do
      name { "Record" }
      title { "Title" }

      trait :example do
        name { "Example" }
      end

      to_create { |obj, _| obj.created_at = "2024-01-01" }
    end
  end
end
