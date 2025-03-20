# FactoryBot::With

[![](https://badge.fury.io/rb/factory_bot-with.svg)](https://badge.fury.io/rb/factory_bot-with)
[![](https://github.com/yubrot/factory_bot-with/actions/workflows/main.yml/badge.svg)](https://github.com/yubrot/factory_bot-with/actions/workflows/main.yml)

FactoryBot::With is a FactoryBot extension that wraps `FactoryBot::Syntax::Methods` to make it a little easier to use.

[FactoryBot における関連の扱いと、factory_bot-with gem を作った話 (Japanese)](https://zenn.dev/yubrot/articles/032447068e308e)

For example, with these factories:

```ruby
FactoryBot.define do
  factory(:blog)
  factory(:article) { blog }
  factory(:comment) { article }
end
```

Instead of writing like this:

```ruby
create(:blog) do |blog|
  create(:article, blog:) { |article| create(:comment, article:) }
  create(:article, blog:) { |article| create_list(:comment, 3, article:) }
end
```

FactoryBot::With allows you to write:

```ruby
create.blog(
  with.article(with.comment),
  with.article(with_list.comment(3)),
)
```

## Installation

On your Gemfile:

```ruby
gem "factory_bot-with"
```

Then, instead of including `FactoryBot::Syntax::Methods`, include `FactoryBot::With::Methods`:

```ruby
# RSpec example
RSpec.configure do |config|
  # ...
  config.include FactoryBot::With::Methods
  # ...
end
```

## What differs from `FactoryBot::Syntax::Methods`?

### Method style syntax

FactoryBot::With overrides the behavior when factory methods are called without arguments.

```ruby
create(:foo, ...)  # behaves in the same way as FactoryBot.create
create             # returns a Proxy (an intermediate) object
create.foo(...)    # is equivalent to create(:foo, ...)
```

This applies to other factory methods such as `build_stubbed`, `create_list`, `with` (described later), etc. as well.

```ruby
build_stubbed.foo(...)
create_list.foo(10, ...)
```

### Smarter interpretation of positional arguments

FactoryBot::With adjusts the behavior of factory methods to accept `Hash`, `Array`, and falsy values (`false` or `nil`) as positional arguments.

```ruby
create.foo({ title: "Recipe" }, is_new && %i[latest hot])
#=> create(:foo, :latest, :hot, title: "Recipe")  if is_new
#   create(:foo, title: "Recipe")                 otherwise
```

### `with`, `with_pair`, and `with_list` operator

FactoryBot::With provides a new operator `with` (and its family).

```ruby
with(:factory_name, ...)
with_pair(:factory_name, ...)
with_list(:factory_name, number_of_items, ...)
```

The result of this operator (`With` instance) can be passed as an argument to factory methods such as `build` or `create`, which can then create additional objects following the result of the factory.

```ruby
create.blog(with.article)
# is equivalent to ...
blog = create.blog
create.article(blog:)
```

The overridden factory methods collect these `with` arguments before delegating object creation to the actual factory methods.

<details>
<summary>Automatic association resolution</summary>

`with` automatically resolves references to ancestor objects based on the definition of the FactoryBot associations.

This automatic resolution takes into account any [traits](https://thoughtbot.github.io/factory_bot/traits/summary.html) in the factories, [aliases](https://thoughtbot.github.io/factory_bot/sequences/aliases.html) in the factories, and [factory specifications](https://thoughtbot.github.io/factory_bot/associations/specifying-the-factory.html) in the associations.

```ruby
FactoryBot.define do
  factory(:video)
  factory(:photo)
  factory(:tag) do
    trait(:for_video) { taggable factory: :video }
    trait(:for_photo) { taggable factory: :photo }
  end
end

create.video(with.tag(text: "latest"))  # resolved as taggable: video
create.photo(with.tag(text: "latest"))  # ...
```

Due to technical limitations, [inline associations](https://thoughtbot.github.io/factory_bot/associations/inline-definition.html) cannot be resolved.

</details>

<details>
<summary>Autocomplete fully-qualified factory name</summary>

For a factory name that is prefixed by the parent object's factory name, the prefix can be omitted.

```ruby
FactoryBot.define do
  factory(:blog)
  factory(:blog_article) { blog }
end

create.blog(with.article) # autocomplete to :blog_article
```

</details>

## Additional features

### `with` as a template

`with` can also be used stand-alone. Stand-alone `with` can be used in place of the factory name. It works as a template for factory method calls.

Instead of writing:

```ruby
let(:story) { create(:story, *story_args, **story_kwargs) }
let(:story_args) { [] }
let(:story_kwargs) { { category: "SF" } }

context "when published more than one year ago" do
  let(:story_args) { [*super(), :published] }
  let(:story_kwargs) { { **super(), start_at: 2.year.ago } }

  # ...
end
```

You can write like this:

```ruby
# Factory methods accept a With instance as a first argument:
let(:story) { create(story_template) }
let(:story_template) { with.story(category: "SF") }

context "when published more than one year ago" do
  let(:story_template) { with(super(), :published, start_at: 2.year.ago) }

  # ...
end
```

### `with` scope syntax for automatic association resolution

By calling `with` without positional arguments, but with keyword arguments that define the relationship between factory names and objects, along with a block, it creates a scope where those objects become candidates for automatic association resolution.

```ruby
let(:blog) { create.blog }

before do
  with(blog:) do
    # Just like when using `create.blog(with.article)`,
    # `blog` is provided as a keyword argument automatically at each `create.article`
    create.article(with.comment)
    create.article(with_list.comment(3))
  end
end
```

The same behavior occurs when a block is passed to factory methods. [^1]

```ruby
create.blog do
  create.article(with.comment)
  create.article(with_list.comment(3))
end
```

[^1]: There is [an incompatible behavior](./lib/factory_bot/with.rb#L121) with FactoryBot. If you want to avoid this, use `Object#tap` manually.

## Development

```bash
git clone https://github.com/yubrot/factory_bot-with
cd gems/factory_bot-with
bin/setup
bundle exec rake --tasks
bundle exec rake
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yubrot/factory_bot-with. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/yubrot/factory_bot-with/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the FactoryBot::With project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/yubrot/factory_bot-with/blob/main/CODE_OF_CONDUCT.md).
