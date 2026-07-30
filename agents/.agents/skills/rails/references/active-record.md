# Active Record — Queries and Writes

## What bypasses your model

These methods operate on the table, not on your objects. That is the point of them, and the
trap:

| Method                            | Skips                                                        |
| --------------------------------- | ------------------------------------------------------------ |
| `update_all`                      | callbacks, validations, **and `updated_at`**                  |
| `delete_all`                      | callbacks, `destroy`, **and `dependent:` rules**              |
| `insert_all` / `upsert_all`       | callbacks, validations, Ruby-side attribute defaults          |
| `update_column` / `update_columns` | callbacks, validations, **and dirty tracking**                 |
| `touch` / `touch_all`             | callbacks, validations, dirty tracking                        |

`update_all` not touching `updated_at` is the one that bites hardest — every cache key derived
from `updated_at` goes stale-but-fresh-looking. If you use it, update the timestamp yourself.

Legitimate uses: fanning out a denormalized foreign key inside a transaction, bulk-importing
rows whose validity you've already established, and throttled cleanup. Everything else should
go through the model.

```ruby
def move_to(new_board)
  transaction do
    update!(board: new_board)
    events.update_all(board_id: new_board.id, updated_at: Time.current)
  end
end
```

## `size` vs `count` vs `length`

| Call     | Behavior                                                                 |
| -------- | ------------------------------------------------------------------------ |
| `count`  | always issues `SELECT COUNT(*)` — **even if the records are loaded**       |
| `length`  | always loads the whole collection into memory, then counts                |
| `size`   | counts in memory if loaded, otherwise issues a COUNT — usually what you want |

**`pluck` has the same problem as `count`.** Both re-query even on a loaded relation, so the
usual "prefer `pluck` over `map(&:id)`" advice inverts once records are in memory:

```ruby
cards = board.cards.preloaded.to_a

cards.pluck(:id)                  # ❌ a fresh query against already-loaded records
cards.map(&:id)                   # ✅ in memory

card.steps.completed.count        # ❌ a COUNT per card, even with steps preloaded
card.steps.count(&:completed?)    # ✅ in memory
```

Use `pluck` to *avoid* loading (`Card.where(...).pluck(:id)`), never after loading.

## Terser query forms

```ruby
Post.where(id: id).first            → Post.find_by(id: id)
Post.where("user_id = ?", user.id)  → Post.where(user: user)      # pass the record
Post.where(...).count > 0           → Post.where(...).exists?
Post.where(...).present?            → Post.where(...).exists?     # avoids loading rows
Post.left_joins(:tags).where(tags: { id: nil })
                                    → Post.where.missing(:tags)   # 6.1+
Post.joins(:tags).distinct          → Post.where.associated(:tags) # 7.0+
```

`find_by` returns nil; `find_by!` raises `RecordNotFound` (→ 404 in a controller). Prefer the
bang form when the record's absence means the request is invalid.

## Preloading is structural, not reactive

Define a named `scope :preloaded` on every model rendered in a list, and pipe collections
through it. N+1 prevention then lives in one reviewable place per model instead of being
rediscovered per controller.

```ruby
scope :with_users, -> {
  preload(creator: [ :avatar_attachment, :account ],
          assignees: [ :avatar_attachment, :account ])
}

scope :preloaded, -> {
  with_users.preload(:column, :tags, :steps, :closure, board: [ :columns ])
}
```

```ruby
@cards = @board.cards.active.preloaded
```

Extract a sub-scope (`with_users`) when a cluster of associations belongs together, so an action
that needs only that subset can ask for it.

### `preload` vs `includes` vs `eager_load`

- **`preload`** — always separate queries, never a JOIN. The default choice inside a
  `preloaded` scope: predictable, and it cannot produce a Cartesian product.
- **`includes`** — Rails picks for you, silently switching to a JOIN when another clause
  references the association. Use it when callers may chain `.where` on the included table.
- **`eager_load`** — forces one LEFT OUTER JOIN. Only when you must filter or sort on the
  associated table in SQL.

`preload` **fails** if you then filter on the association; `includes` handles it by switching
strategy. That difference is the whole reason to choose deliberately.

### N+1 traps that survive a `preloaded` scope

- **A chained scope over a preloaded association** re-queries — see `count` above.
- **Associations not in the scope**, reached from a list partial. Audit what the partial
  touches, not just what the controller loads.
- **Per-row counts** with no counter cache — `column.cards.active.count` inside a loop is a
  COUNT per row. Add a counter cache or denormalize.
- **Polymorphic gaps** — each `*_type` variant needs its own sub-associations preloaded, or
  traversing them queries. Audit every type the column can hold.
- **Helpers reaching further than the controller loaded** — an avatar helper calling
  `user.account.slug` is fine under a scope that preloads `:account` and fires a query per row
  under one that doesn't.

Fragment caching softens a cold N+1 to once-per-record rather than once-per-request, but fix
the scope first — see [`views-and-helpers.md`](views-and-helpers.md).

## Batching

Never load an unbounded set into memory:

```ruby
Card.find_each { |card| card.reindex }              # batches of 1000 by default

Card.in_batches do |batch|
  batch.pluck(:id)                                   # stream ids without materializing objects
end

comments.in_batches.destroy_all                      # batched, callbacks still run
```

`delete_all` returns the number of affected rows, which makes a throttled cleanup loop trivial:

```ruby
def self.cleanup(batch_size: 500, pause: 0.1)
  sleep pause until stale.limit(batch_size).delete_all.zero?
end
```

For a long scan, add `start:` so the job can resume — see [`jobs.md`](jobs.md).

## Uniqueness belongs in the database

`validates :x, uniqueness: true` issues a SELECT then an INSERT. Two concurrent requests both
pass the SELECT. It is a race, always. Put a unique index on the column and treat the exception
as the control flow:

```ruby
def assign(user)
  assignment = assignments.create(assignee: user, assigner: Current.user)
  track_event :assigned, assignee_ids: [ user.id ] if assignment.persisted?
rescue ActiveRecord::RecordNotUnique
  # already assigned — nothing to do
end
```

Keep the validation too if you want a friendly form error, but the index is what makes it
correct.

## `create_or_find_by` and stale dirty tracking

`find_or_create_by` races (SELECT then INSERT); `create_or_find_by` inverts it (INSERT, rescue
the unique violation, then SELECT) and is the safer default.

A subtler failure follows it. When you update the record you just found, Rails' dirty tracking
compares against the **in-memory** value — which may be stale if a concurrent process changed
the row. An unchanged-looking attribute is then omitted from the UPDATE:

```ruby
unless notification.previously_new_record?
  # force the column into the UPDATE even if it looks unchanged in memory
  notification.source_type_will_change!
  notification.update!(source: source, read_at: nil)
end
```

`*_will_change!` is the escape hatch for "write this column regardless of what I think its old
value was."

## Locking

Prefer **pessimistic** locking for row-scoped counters and ledgers. Optimistic locking
(`lock_version`) makes the caller handle a retry, which for a counter is almost never what you
want:

```ruby
def redeem_if(&block)
  with_lock do                       # SELECT ... FOR UPDATE inside a transaction
    increment!(:usage_count) if active? && block.call(account)
  end
end
```

The block runs **inside** the lock, so the check and the side effect are atomic.

**Sort before locking.** Two processes locking the same rows in different orders deadlock.
Impose a total order:

```ruby
# processing recipients in a stable order avoids deadlocks between overlapping jobs
recipients.sort_by(&:id).each { |recipient| ... }
```

`increment!` is a single atomic UPDATE and returns the record, so it needs no lock of its own:

```ruby
self.number ||= account.increment!(:cards_count).cards_count
```

## Ledger plus snapshot

For a running total that must stay cheap to read: append immutable delta rows, and collapse
them into a snapshot under a lock, tracking a monotonic cursor so the operation is idempotent
and re-runnable.

```ruby
total.with_lock do
  latest_id = entries.maximum(:id)
  if latest_id && total.last_entry_id != latest_id
    scope = entries.where(id: ..latest_id)
    scope = scope.where.not(id: ..total.last_entry_id) if total.last_entry_id
    total.update!(bytes: total.bytes + scope.sum(:delta), last_entry_id: latest_id)
  end
end
```

Expose both a fast, possibly-stale reader and an exact one, and let callers choose.

## Two-cursor read consistency

When a reconciliation scan is too long to hold a lock, capture the cursor **before and after**.
If it moved, the scan saw a moving target — abort rather than write a wrong delta:

```ruby
def reconcile
  before = entries.maximum(:id)
  real   = calculate_real_total
  after  = entries.maximum(:id)
  return false if before != after      # entries arrived mid-scan; retry later
  ...
end
```

Put the retry in the caller (the job), not in the model, so it doesn't amplify.

## Bulk insert on an association

`insert_all` inside a `has_many` extension block reads naturally and keeps the operation where
it belongs. `proxy_association.owner` is the parent:

```ruby
has_many :accesses, dependent: :delete_all do
  def grant_to(users)
    Access.insert_all(
      Array(users).map { |user| { board_id: proxy_association.owner.id, user_id: user.id } }
    )
  end
end
```

`insert_all` skips Ruby-side defaults, so any column whose default is generated in Ruby (not by
the database) must be supplied explicitly. Use `insert_all!` when a constraint violation should
raise rather than be silently skipped.

## Ordering needs a tiebreaker

`order(:created_at)` over non-unique values yields a nondeterministic sequence — pagination
duplicates and drops rows:

```ruby
scope :chronologically, -> { order created_at: :asc, id: :desc }
```

Related: at `load_defaults 8.1`, `first`/`last` **raise** `MissingRequiredOrderError` on a
relation with no `order` and no `implicit_order_column` — see
[`versions.md`](versions.md).
