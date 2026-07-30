# Aggregates and Boundaries

Identify the roots before modeling anything else — they shape every decision downstream.

A **root** is a model that:

1. **owns** its dependents — destroying it destroys them (`dependent: :destroy`)
2. can be **queried independently** — it's a legitimate starting point for a query
3. is a **transaction boundary** — a change to it and its dependents commits as one unit

## A worked domain

The shape a multi-tenant app converges on:

| Model              | Role                                                                            |
| ------------------ | ------------------------------------------------------------------------------- |
| `Account`          | the tenant. Owns everything else; every table carries `account_id`               |
| `Identity` / `User` | authentication (global) vs membership (per-tenant) — **do not conflate these**  |
| `Board`            | a workspace and an access-control boundary                                      |
| `Card`             | the rich work item — most behavior lives here, factored into concerns           |
| `Event`            | cross-cutting immutable audit log; belongs to no single root                     |

`Identity` vs `User` is the one people collapse and regret. An identity is an email that can
sign in; a user is that identity's membership in one account, with a role. Merging them makes
"the same person in two accounts" unrepresentable.

## `dependent: :destroy` is how you read ownership

It is the declaration of the boundary, not a cleanup detail:

```ruby
class Board < ApplicationRecord
  has_many :columns, dependent: :destroy   # a column has no life without its board
  has_many :cards                          # cards outlive a board move — not owned here
end
```

**If destroying the parent should _not_ destroy the child, the child is its own root.** That
single question resolves most modeling arguments.

See the `dependent:` cost table in [`models.md`](models.md) — the choice between `:destroy`
and `:delete_all` is about callbacks and nested dependents, not about style.

## Thin models aren't anemic — they're focused

A `Closure`, `Tagging`, `NotNow`, or `Column` with three columns and no methods is **correct
design**, not an unfinished one. Behavior belongs where the data is rich; a record whose whole
job is to exist and record who/when needs no methods at all.

```ruby
class Closure < ApplicationRecord
  belongs_to :card
  belongs_to :user
end
```

That is a complete model. Resist the urge to give it responsibilities to justify the file.

## When you need a new model rather than a column

You almost certainly need a model — not a boolean, not an `enum` — when **any** of these hold:

- the concept has its own **lifecycle**: created and destroyed independently of its parent
- you want to record **who** and **when** the state changed
- **more than one** can attach to the same parent
- it should participate in **joins**, so scopes can be composed over it

A `closed_at` timestamp answers "when" but not "by whom", can't be extended, and forces every
query to special-case `NULL`. A `Closure` record answers all of it and gives you
`joins(:closure)` and `where.missing(:closure)` for free — see the state-record section of
[`models.md`](models.md).

The counter-question matters too: if none of those hold, **don't** add a model. A genuine
boolean is a boolean.

## Cross-cutting concepts get their own root

Some concepts don't belong to any one aggregate — audit events, notifications, reactions,
search records. Give each its own root plus a polymorphic association, and let models opt in
through a concern:

```ruby
class Event < ApplicationRecord
  belongs_to :eventable, polymorphic: true
  belongs_to :creator, class_name: "User"
end

module Eventable
  extend ActiveSupport::Concern

  included do
    has_many :events, as: :eventable, dependent: :destroy
  end

  def track_event(action, **particulars)
    events.create!(action:, particulars:)
  end
end
```

One `events` table then drives the activity timeline, notifications, and webhooks without any
of those coupling to each other, and without each new model needing its own audit plumbing.

The mistake this prevents: building a second, parallel "activity" or "history" system beside
the first because the first wasn't polymorphic.

## Deriving the tenant

Denormalize `account_id` onto every table and let each model derive it from its own parent,
rather than reading ambient state:

```ruby
class Card < ApplicationRecord
  belongs_to :account, default: -> { board.account }
end

class Comment < ApplicationRecord
  belongs_to :account, default: -> { card.account }
end
```

Deriving from the **graph** rather than from a thread-local means the write is correct in a
job, a console session, an import, or a rake task — anywhere no request set the ambient
tenant. Reserve `default: -> { Current.account }` for roots that genuinely have no parent.

**Avoid `default_scope` for tenancy.** It surprises you in the console, leaks into joins and
raw SQL, and is painful to undo. Scope through a user-owned association at the query's entry
point instead — see the scoping-concern pattern in
[`controllers-and-routes.md`](controllers-and-routes.md).

## Aggregates and transactions

A transition that touches a root and its dependents belongs in **one** method on the root,
wrapped in one transaction:

```ruby
def close(user: Current.user)
  unless closed?
    transaction do
      not_now&.destroy
      create_closure! user: user
      track_event :closed, creator: user
    end
  end
end
```

Three writes across three tables, one boundary, one intention-revealing name. Note that
nested `transaction` calls **join** the enclosing transaction rather than nesting — see
[`transactions-and-callbacks.md`](transactions-and-callbacks.md) before assuming a savepoint.
