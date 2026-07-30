# Transactions and Callbacks

## Callbacks for passive effects, methods for transitions

| Use a callback for                                     | Use an explicit method for              |
| ------------------------------------------------------ | --------------------------------------- |
| derived timestamps and counters                        | a state change a user meant to make     |
| search indexing                                        | anything with a name (`close`, `publish`) |
| notifications and broadcasts                           | anything a caller should be able to skip |
| auto-subscribing an author to their own comment        | anything taking arguments               |

The test: would a developer be surprised that this happened? Surprising things go in a named
method. `card.close` is discoverable; a `before_save` that closes cards is not.

## `after_commit` makes very different guarantees than `after_save`

By the time `after_commit` runs, **the data is already committed**. Consequences:

- Raising in `after_commit` does **not** roll back. The write stands and the exception
  propagates.
- That exception **skips every remaining** `after_commit` / `after_rollback` callback on the
  same transaction. One failing broadcast silently cancels the indexing that was queued
  behind it.
- Callbacks run in **definition order** as of Rails 7.1 (they were reversed before).
- `after_commit` does not fire until the **outermost** transaction commits, which is why a
  test asserting on its side effect from inside `transaction do` sees nothing.

Practical split — atomic work on `after_create`, effects that leave the process on
`after_create_commit`:

```ruby
after_create :bundle                      # a DB write that must be atomic with this row
after_create_commit :deliver_later        # leaves the process; must not run on a rollback
```

**Identically-named callbacks are deduplicated.** Two `after_commit :sync` declarations
collapse to one — the last. Distinguish them with `on:`:

```ruby
after_commit :sync, on: :create
after_commit :sync, on: :update
```

## Enqueuing a job inside a transaction: it depends on the backend

The most consequential thing in this file. The question is whether the queue can hand your job
to a worker **before** the surrounding transaction commits.

| Backend                                    | Job record lives      | Enqueue inside a transaction                                |
| ------------------------------------------ | --------------------- | ----------------------------------------------------------- |
| Database-backed (Solid Queue, GoodJob, DJ) | the same database     | **Safe and transactional** — invisible until commit; rolls back with it |
| Redis-backed (Sidekiq, Resque)             | out-of-band in Redis  | **A race** — a worker can pick it up and hit `RecordNotFound` |

So there is no single correct answer, and a codebase mid-migration between the two has
**both** answers running at once. Check which base class the job inherits from before deciding.

For a Redis-backed queue, either enqueue from `after_commit`, or set the job class to defer:

```ruby
class NotificationJob < ApplicationJob
  self.enqueue_after_transaction_commit = true
end
```

For a database-backed queue, deferring is unnecessary and actively *removes* a guarantee — the
job row would no longer roll back with the transaction that created it.

### `enqueue_after_transaction_commit` — the version trap

**A leftover symbol value (`= :never`) silently inverts to its opposite on Rails 8.1**, because
a Symbol is truthy. Convert symbol assignments to booleans before upgrading — full version
history and the mechanism in [`versions.md`](versions.md).

## `return` and `break` out of a transaction now commit

As of Rails 8.0 (`commit_transaction_on_non_local_return` was removed), a non-local exit from a
`transaction` block **commits**:

```ruby
Account.transaction do
  account.update!(plan: "pro")
  return if account.trialing?   # ⚠️ commits the update — does NOT roll back
end
```

Only a raise — or `ActiveRecord::Rollback`, which rolls back without propagating — undoes the
work. If a guard should abandon the transaction, raise.

## Nested `transaction` blocks join the parent

A nested `transaction` call does **not** create a savepoint. It joins the enclosing
transaction, so a rollback inside it rolls back everything:

```ruby
ActiveRecord::Base.transaction do          # outer
  ActiveRecord::Base.transaction do        # joins the outer — not a savepoint
    raise ActiveRecord::Rollback           # ⚠️ silently swallowed here; outer still commits
  end
end
```

`ActiveRecord::Rollback` is caught by the block that receives it, so raising it in a joined
inner block does nothing useful. Pass `requires_new: true` for a real savepoint — and reach for
that deliberately, not by default.

Signal failure by raising (`update!`, `create!`, `find_by!`) and let it propagate. Most
well-shaped code needs neither `requires_new:` nor `ActiveRecord::Rollback`.

## Rescuing inside a transaction leaves Postgres aborted

On Postgres, once a statement fails, the transaction enters an aborted state. Swallowing the
error keeps the block going, and **every subsequent statement fails** with "current transaction
is aborted" — reported far from the real cause:

```ruby
ActiveRecord::Base.transaction do
  record.save!
rescue => e                 # ⚠️ transaction is now aborted
  Rails.logger.warn(e)
  other.save!               # fails with a misleading error
end
```

Rescue **outside** the transaction, or use a savepoint (`requires_new: true`) around the part
allowed to fail.

## Dirty state does not survive to `after_*_commit`

`saved_change_to_*` reflects the **last save**. Across a transaction with more than one save —
or a `touch` from an association — the change you cared about is gone by commit time. Capture a
flag while you can still see it:

```ruby
before_update :remember_if_preview_changed
after_update_commit :broadcast_preview, if: :preview_changed?

private
  def remember_if_preview_changed
    @preview_changed ||= title_changed? || column_id_changed?
  end
```

The `||=` matters: it **accumulates** across several updates inside one transaction, where a
plain `=` would let the last save clear it.

## Snapshot associations in `before_destroy`

By `after_destroy_commit`, a cascading delete may have removed the parent, so `record.account`
raises. Capture what you need while the graph is intact:

```ruby
before_destroy :snapshot_context        # ids only — those still work on a destroyed object
after_destroy_commit :record_detachment
```

Also guard enqueues against records destroyed in the same transaction:

```ruby
def clean_up_later
  CleanupJob.perform_later(user, board) unless user.destroyed?
end
```

## `touch` skips dirty tracking

`touch` writes `updated_at` without running validations, callbacks, or dirty tracking. If a
downstream callback keys off the attribute having changed, use `update!` instead:

```ruby
def touch_last_active_at
  # not `touch` — callbacks need to see the attribute change
  update!(last_active_at: Time.current)
end
```

The inverse tool is `no_touching`, for when a write shouldn't register as activity:

```ruby
Card.no_touching do
  watch_by creator
end
```

## Suppressing a callback chain deliberately

For bulk operations where a ledger or broadcast would be wrong, a scoped switch beats
detaching callbacks:

```ruby
class Storage::Entry < ApplicationRecord
  thread_mattr_accessor :recording, default: true

  def self.suppressing_recording
    original, self.recording = self.recording, false
    yield
  ensure
    self.recording = original
  end
end
```

`ensure` is not optional — without it, one raised exception leaves the switch off for the rest
of the thread's life.

## Domain lifecycle callbacks

For a lifecycle that isn't an Active Record one, define your own rather than overloading
`before_destroy`:

```ruby
define_callbacks :incinerate

def incinerate
  run_callbacks :incinerate do
    account.destroy
  end
end
```

This lets other code — including an engine — hook the domain event without knowing how it's
implemented.
