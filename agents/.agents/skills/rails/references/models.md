# Models

## What a good model looks like

A complete production model. 30 lines, and nothing in it is ceremony:

```ruby
class Comment < ApplicationRecord
  include Attachments, Eventable, Mentions, Promptable, Searchable, Storage::Tracked

  belongs_to :account, default: -> { card.account }
  belongs_to :card, touch: true
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_many :reactions, -> { order(:created_at) }, as: :reactable, dependent: :delete_all

  has_rich_text :body

  validate :card_is_commentable

  scope :chronologically, -> { order created_at: :asc, id: :desc }
  scope :preloaded, -> { with_rich_text_body.includes(reactions: :reacter) }
  scope :by_system, -> { joins(:creator).where(creator: { role: :system }) }
  scope :by_user, -> { joins(:creator).where.not(creator: { role: :system }) }

  after_create_commit :watch_card_by_creator

  delegate :publicly_accessible?, :accessible_to?, :board, :watch_by, to: :card

  def to_partial_path
    "cards/#{super}"
  end

  private
    def watch_card_by_creator
      card.watch_by creator
    end
end
```

Read the association block closely — that is the whole lesson of this file:

- `belongs_to :card, touch: true` — no `class_name:`, no `foreign_key:`.
- `belongs_to :creator, class_name: "User"` — **`class_name:` alone.** The column is still
  inferred as `creator_id`.
- `default: -> { … }` is what keeps controllers to one line — the owner and the tenant are
  set by the model, not passed in by every caller.
- `scope :chronologically` orders by `created_at` **and** `id` — a non-unique sort column
  always needs a tiebreaker.

_Source: fizzy — `app/models/comment.rb`._

## Rails infers almost everything from the association name

Every option you pass that matches the inference is noise, and noise hides the one option
that carries meaning.

| Option         | `belongs_to :author` infers               | `has_many :comments` on `Post` infers    |
| -------------- | ----------------------------------------- | ---------------------------------------- |
| `class_name:`  | `"Author"` — the name, camelized          | `"Comment"` — singularized, camelized    |
| `foreign_key:` | `"author_id"` — **the association name**  | `"post_id"` — **the owning model's name** |
| `primary_key:` | `"id"`                                    | `"id"`                                   |
| `optional:`    | `false` (required) since Rails 5          | n/a                                      |
| `inverse_of:`  | auto-detected for conventional names      | auto-detected for conventional names     |

Verified against Rails 8.0.5 — `activerecord/lib/active_record/reflection.rb`:

- `derive_foreign_key` (:827) is literally `"#{name}_id"` when `belongs_to?`, and
  `active_record.model_name.to_s.foreign_key` otherwise.
- `derive_class_name` (:821) is `name.to_s`, singularized if a collection, camelized.

## `class_name:` and `foreign_key:` are inferred from different things

They are independent. The **association name** drives the column; the association name also
drives the class. Overriding one does not oblige you to override the other — and this is the
single most common piece of redundancy in generated Rails code.

```ruby
belongs_to :creator, class_name: "User"                                # ✅ column inferred: creator_id
belongs_to :creator, class_name: "User", foreign_key: "creator_id"     # ❌ foreign_key is redundant
belongs_to :creator, class_name: "User", foreign_key: "created_by_id"  # ✅ earns both — column differs
```

The first form is production code (`fizzy/app/models/comment.rb:6`). You need
`foreign_key:` only when the **column** doesn't match the **association name**.

## Delete on sight

```ruby
belongs_to :user, class_name: "User"                       # inferred
belongs_to :user, foreign_key: "user_id"                   # inferred
belongs_to :user, primary_key: "id"                        # inferred
belongs_to :user, optional: false                          # the default since Rails 5
has_many :comments, class_name: "Comment"                  # inferred
has_many :comments, foreign_key: "post_id"                 # inferred from Post
has_many :comments, inverse_of: :post                      # auto-detected
self.table_name = "posts"                                  # inferred on Post
validates :name, presence: { message: "can't be blank" }   # that is the default message
```

## What genuinely earns an option

| Option                | When                                                                       |
| --------------------- | -------------------------------------------------------------------------- |
| `optional: true`      | the association really is optional — **this is the one you must say**       |
| `class_name:`         | the association name differs from the class (`:creator` → `User`)           |
| `foreign_key:`        | the **column** differs from the association name                           |
| `polymorphic: true`   | the class genuinely can't be inferred — plus `as:` on the inverse           |
| `as:`                 | the inverse of a polymorphic `belongs_to`                                   |
| `touch: true`         | the parent's `updated_at` should move with the child (cache invalidation)   |
| `counter_cache:`      | you read the count far more often than you write the collection             |
| `inverse_of:`         | with `:through`, a custom `foreign_key:`, or polymorphic — detection fails  |
| `dependent:`          | always decide it explicitly; see below                                      |
| `default: -> { … }`   | the owner/tenant is derivable — this is what keeps controllers thin         |
| a scope block         | the association has an inherent order or filter                             |

## `dependent:` is a cost decision, not a default

Agents reach for `:destroy` reflexively. It is the most expensive option:

| Value                  | Queries                    | Callbacks | Nested `dependent:` |
| ---------------------- | -------------------------- | --------- | ------------------- |
| `:destroy`             | one per record (each is instantiated) | run       | honored             |
| `:delete_all`          | 1                          | skipped   | **ignored**         |
| `:nullify`             | 1 UPDATE                   | skipped   | n/a                 |
| `:restrict_with_error` | 1 COUNT                    | n/a       | n/a                 |

Use `:destroy` when children have their own cleanup (attachments, nested children, an audit
trail). Use `:delete_all` for leaf join records — but only after confirming nothing hangs
off them, because their own `dependent:` rules will not fire.

## Namespaced class resolution walks outward

An inferred class name resolves relative to the enclosing module and walks outward, so
inside `Billing::Invoice`:

```ruby
module Billing
  class Invoice < ApplicationRecord
    belongs_to :customer          # finds Billing::Customer, else ::Customer
    belongs_to :payer, class_name: "::Customer"   # forces top-level when both exist
  end
end
```

`compute_class` (`reflection.rb:496`) delegates to `compute_type`, which performs that walk.
When both a namespaced and a top-level class exist, an unqualified name silently picks the
namespaced one.

## State belongs in a record, not a boolean

A boolean column tells you _that_ something happened. A record tells you **who** and
**when**, and it composes into queries:

```ruby
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy

    scope :closed, -> { joins(:closure) }
    scope :open,   -> { where.missing(:closure) }

    scope :recently_closed_first, -> { closed.order(closures: { created_at: :desc }) }
    scope :closed_by, ->(users) { closed.where(closures: { user_id: Array(users) }) }
  end

  def closed?    = closure.present?
  def closed_by  = closure&.user
  def closed_at  = closure&.created_at
end
```

`where.missing(:closure)` (Rails 6.1+) is the "no associated record" idiom — no manual LEFT
JOIN. This is also what makes REST-shaped controllers fall out: a `Closure` record is a
resource, so closing becomes `POST /cards/:id/closure` and reopening `DELETE`. See
[`controllers-and-routes.md`](controllers-and-routes.md).

_Source: fizzy — `app/models/card/closeable.rb`._

## Intention-revealing methods

One model method contains the whole transition — mutation, state record, and audit event — so
no caller ever reassembles it, and callers write `card.close`. Name methods for the domain verb
(`close`, `publish`, `gild`), and don't add `!` unless a non-bang counterpart exists — see
[`style.md`](style.md). Worked example in [`concerns.md`](concerns.md).

## `normalizes` over a `before_validation`

```ruby
normalizes :title, with: -> { it.downcase }
normalizes :email_address, with: ->(value) { value.strip.downcase.presence }
```

`normalizes` (Rails **7.1**, not 8.x) also normalizes **finder arguments**, so
`Identity.find_by(email_address: " A@B.com ")` matches. A `before_validation` callback
cannot do that. Note the Ruby 3.4 `it` implicit block parameter.

## Validations and the database

Uniqueness enforced only in Ruby is a race. Put a unique index on the column and let the
database be the authority — see the `rescue ActiveRecord::RecordNotUnique` idiom in
[`active-record.md`](active-record.md).
