# FactoryBot::With

[![](https://badge.fury.io/rb/factory_bot-with.svg)](https://badge.fury.io/rb/factory_bot-with)
[![](https://github.com/yubrot/factory_bot-with/actions/workflows/main.yml/badge.svg)](https://github.com/yubrot/factory_bot-with/actions/workflows/main.yml)

FactoryBot::With is a FactoryBot extension that enhances usability by wrapping factory methods.

[FactoryBot における関連の扱いと、factory_bot-with gem を作った話 (Japanese)](https://zenn.dev/yubrot/articles/032447068e308e)

For example, given these factories:

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

FactoryBot::With allows you to write like this:

```ruby
create.blog do
  create.article { create.comment }
  create.article { create_list.comment(3) }
end
```

## Installation

Add the following line to your Gemfile:

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

Alternatively, these factory methods are also provided as class methods of `FactoryBot::With`.

## What differs from `FactoryBot::Syntax::Methods`?

### Method-style syntax

FactoryBot::With overrides the behavior of factory methods called without arguments.

```ruby
create(:foo, ...)  # normal usage
create             # returns a Proxy (an intermediate) object
create.foo(...)    # is equivalent to create(:foo, ...)

# This also applies to other factory methods:
build_stubbed.foo(...)
create_list.foo(10, ...)
```

### Smarter interpretation of positional arguments

FactoryBot::With allows factory methods to accept `Hash`, `Array`, and falsy values (`false` or `nil`) as positional arguments[^1].

[^1]: The idea for this behavior came from JavaScript libraries such as [clsx](https://github.com/lukeed/clsx).

```ruby
create.foo({ title: "Recipe" }, is_new && %i[latest hot])
#=> create(:foo, :latest, :hot, title: "Recipe")  if is_new
#   create(:foo, title: "Recipe")                 otherwise
```

### `with`, `with_pair`, and `with_list` operator

FactoryBot::With introduces new operators: `with` (and its family).

- `with(:factory_name, ...)`
- `with_pair(:factory_name, ...)`
- `with_list(:factory_name, number_of_items, ...)`

These operators produce a `With` instance. This instance can be passed as an argument to factory methods such as `build` or `create`:

```ruby
create.blog(with.article(with.comment))
```

When the factory method is called, it first collects and removes `With` arguments, then delegates the actual object creation to the standard FactoryBot factory method, and finally creates additional objects based on the factory definition. Above example is equivalent to:

```ruby
_tmp1 = FactoryBot.create(:blog)
_tmp2 = FactoryBot.create(:article, blog: _tmp1)
_tmp3 = FactoryBot.create(:comment, article: _tmp2)
# Here, `blog: _tmp1` and `article: _tmp2` are automatically completed by AAR (described later)
```

<details>
<summary>Automatic Association Resolution (AAR)</summary>

`with` automatically resolves references to ancestor objects based on the definition in your FactoryBot factories.

This automatic resolution takes into account any [traits](https://thoughtbot.github.io/factory_bot/traits/summary.html), [aliases](https://thoughtbot.github.io/factory_bot/sequences/aliases.html), and [factory specifications](https://thoughtbot.github.io/factory_bot/associations/specifying-the-factory.html) in the definition.

```ruby
FactoryBot.define do
  factory(:video)
  factory(:photo)
  factory(:tag) do
    # `tag` potentially has an association on `taggable` field. `taggable` is either `video` or `photo`.
    trait(:for_video) { taggable factory: :video }
    trait(:for_photo) { taggable factory: :photo }
  end
end

create.video(with.tag(text: "latest"))  # resolved as `taggable: <created video object>`
create.photo(with.tag(text: "latest"))  # resolved as `taggable: <created photo object>`
```

Due to technical limitations, [inline associations](https://thoughtbot.github.io/factory_bot/associations/inline-definition.html) are not taken into account.

</details>

<details>
<summary>Factory Name Completion (FNC)</summary>

For a factory name that is prefixed by the ancestor object's factory name, the prefix can be omitted.

```ruby
FactoryBot.define do
  factory(:blog)
  factory(:blog_article) { blog }
end

create.blog(with.article) # completes to :blog_article
```

</details>

### Implicit context scope

FactoryBot::With factory methods can accept a block argument, just like standard FactoryBot. However, in FactoryBot::With, nested factory method calls within a block recognize ancestor objects. This means that nested factory method calls perform AAR and FNC in the same way as the `with` operator.

```ruby
# Instead of writing:
create.blog(with.article(with.comment))
# You can write:
create.blog { create.article { create.comment } }
# ^ This works in the same way as:
create(:blog) do |blog|
  create(:article, blog:) do |article|
    create(:comment, article:)
  end
end
```

<details>
<summary>Incompatible behavior when calling <code>_list</code> or <code>_pair</code> factory methods with a block</summary>

To align the behavior with the `with_list` operator, there is [an incompatible behavior](./lib/factory_bot/with.rb#L121) compared to standard FactoryBot:

```ruby
# This code creates a blog with 2 articles, each with a comment in standard FactoryBot:
# This does not work in FactoryBot::With!
create(:blog) do |blog|
  create_list(:article, 2, blog:) do |articles| # yielded *once* with an array of articles
    articles.each { |article| create(:comment, article:) }
  end
end

# In FactoryBot::With, blocks are yielded for each object. So we must write like this:
create.blog do |blog|
  create_list.article(2, blog:) do |article| # yielded *for each article*
    create.comment(article:)
  end
end

# Again, you can simplify this by (1)omitting the block or (2)using the `with` operator:
create.blog { create_list.article(2) { create.comment } }  # (1)
create.blog(with_list.article(2, with.comment))            # (2)
```

If you want to avoid this incompatibility, you can use `Object#tap`.

</details>

## Additional features

### Implicit context scope with existing objects

By calling `with` without positional arguments, but with keyword arguments that define the relationship between factory names and objects, along with a block, it creates a context scope where those objects become candidates for AAR and FNC.

```ruby
let(:blog) { create.blog }

before do
  with(blog:) do
    # Just like `create.blog { ... }`,
    # the `blog` object is available for AAR and FNC in the following `create.article` calls:
    create.article(with.comment)
    create.article(with_list.comment(3))
  end
end
```

`with_list` works similarly to `with`, except that it accepts arrays as its values:

```ruby
blog = create.blog
articles = create_list.article(2, blog:)
with_list(article: articles) { create.comment } # yielded *for each article*
```

</details>

### `with` as a factory method call template

A `With` instance can also be used as a template for factory method calls.

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
