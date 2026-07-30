# Concerns

The primary unit of composition. **One concern = one cohesive behavior** — the associations,
scopes, callbacks, and methods that belong to a single trait, kept together.

A concern is not a place to park methods to make a file shorter. If you can't name the trait,
it isn't a concern.

## Anatomy

```ruby
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy

    scope :closed, -> { joins(:closure) }
    scope :open,   -> { where.missing(:closure) }
  end

  def closed? = closure.present?

  def close(user: Current.user)
    unless closed?
      transaction do
        create_closure! user: user
        track_event :closed, creator: user
      end
    end
  end
end
```

Everything about closing is in one file: the association, the queries, the predicates, and the
transition. That is the test — could you delete this file and remove the whole feature?

- **`included do`** — anything evaluated in the class body: associations, scopes, callbacks,
  validations, `delegate`. This is the overwhelming default.
- **Instance methods** — at module level, outside `included do`.
- **`class_methods do`** — genuine class-level API only. **Scopes are not class methods**;
  they go in `included do`.

## Two locations, two meanings

| Location                            | Means                                                         |
| ----------------------------------- | ------------------------------------------------------------- |
| `app/models/card/closeable.rb`      | `Card::Closeable` — behavior specific to `Card`                |
| `app/models/concerns/searchable.rb` | `Searchable` — a trait shared across unrelated models          |

Namespacing under the model is the default for anything only that model does. Reach for a flat
shared concern only when a second model genuinely needs the same trait.

## The flat + namespaced pair

When a trait is shared but each model implements it differently, use both: a **flat** concern
carrying the generic behavior and a documented contract, and a **namespaced** concern per model
supplying that model's implementation.

```ruby
# app/models/concerns/searchable.rb — generic, with the contract stated
module Searchable
  extend ActiveSupport::Concern

  # Models must implement:
  #   search_title    — title string or nil
  #   search_content  — content string
  #   searchable?     — whether this record should be indexed
  ...
end
```

```ruby
# app/models/card/searchable.rb — Card's implementation of that contract
module Card::Searchable
  extend ActiveSupport::Concern

  included do
    include ::Searchable

    scope :mentioning, ->(query, user:) { ... }
  end

  def search_title = title
  def searchable?  = published?
end
```

The model then includes **only the namespaced one** — `Card` includes `Searchable`, which
Zeitwerk resolves to `Card::Searchable` because of the enclosing namespace. Note the `::` in
`include ::Searchable`: without it, Ruby would find `Card::Searchable` and recurse.

**Write the contract down as a comment.** A template-method protocol that lives only in the
author's head is the thing that rots.

## Template methods

Give the flat concern a default, and let each model override:

```ruby
# in the flat concern, under private
private
  def mentionable?  = true
  def should_check_mentions? = false
```

```ruby
# in the namespaced concern
included do
  include ::Mentions

  def mentionable? = published?
end
```

Two subtleties that bite:

- Overriding inside `included do` defines the method on the **class**, which quietly promotes
  it to public even when the default was private. Usually harmless; occasionally surprising.
- For a contract with no sensible default, raise instead of returning nil:

  ```ruby
  def calculate_storage_bytes
    raise NotImplementedError, "#{self.class} must implement calculate_storage_bytes"
  end
  ```

## Pluggable behavior: `class_attribute` + a registrar

When something optional needs to register itself at boot:

```ruby
module Notification::Pushable
  extend ActiveSupport::Concern

  included do
    class_attribute :push_targets, default: []
  end

  class_methods do
    def register_push_target(target)
      push_targets << target unless push_targets.include?(target)
    end
  end
end
```

Registration happens from an initializer — and it must use `to_prepare`, not
`after_initialize`, or a code reload in development silently resets it. See
[`boot-and-autoloading.md`](boot-and-autoloading.md).

## `prepend` for framework classes

`include` puts a module **behind** the class's own methods, so it can't override them. To wrap
a method a framework already defines — and call `super` — use `prepend`:

```ruby
module AccountTenanted
  extend ActiveSupport::Concern

  prepended do
    around_perform :with_account_context
  end

  def serialize
    super.merge("account" => @account&.to_gid)
  end
end
```

Note `prepended do`, not `included do`. Reserve this for extending code you don't own —
inside your own models, plain overriding is clearer.

## Composition order can be load-bearing

```ruby
include Accessor, Assignee, Attachable, Configurable, Named, Role
include Timelined # Depends on Accessor
```

When one concern needs another's associations or callbacks already declared, the include order
matters and **nothing enforces it**. Comment it at the include site.

The same applies to controller concerns — an authorization concern whose predicate reads what
an authentication concern populated must come second. See
[`controllers-and-routes.md`](controllers-and-routes.md).

## When not to use a concern

- **Stateless computation** → a PORO. A concern that touches no state and no associations is
  just a namespace with extra indirection.
- **One method** → put it on the model.
- **Grouping by layer** (`Validations`, `Callbacks`, `Scopes`) → this splits one behavior
  across three files, which is the opposite of the point. Group by **trait**, never by
  mechanism.
- **Hiding size.** A 400-line model split into six concerns that all reference each other is
  still a 400-line model. Concerns are for cohesion; if the model is doing too much, the fix
  is usually a new model — see [`aggregates.md`](aggregates.md).
