# Advanced Rails composition patterns

These extend the core patterns in `SKILL.md`. Reach for them when the situation
calls for it — a cross-cutting audit trail, cascading configuration, or search at
scale. They are power-user concerns, not first-read material.

## 8. Event as the Universal Audit Trail

A single polymorphic `events` table records every domain-meaningful action. It drives notifications, webhooks, broadcasts, and the activity timeline — without any of those concerns being coupled to each other.

### Structure

```ruby
class Event < ApplicationRecord
  belongs_to :account
  belongs_to :board                            # scoping for query/access
  belongs_to :creator, class_name: "User"
  belongs_to :eventable, polymorphic: true     # the thing that changed
  store_accessor :particulars                  # JSON for per-action data

  after_create        -> { eventable.event_was_created(self) }   # in-tx side effects
  after_create_commit :dispatch_webhooks                          # post-tx async
  after_create_commit :notify_recipients_later                    # post-tx async
end
```

### Emitting events

Models include `Eventable` and call `track_event` from their intention-revealing methods:

```ruby
module Eventable
  extend ActiveSupport::Concern

  def track_event(action, creator: Current.user, board: self.board, **particulars)
    if should_track_event?
      board.events.create!(
        action: "#{eventable_prefix}_#{action}",
        creator: creator,
        board: board,
        eventable: self,
        particulars: particulars
      )
    end
  end

  def should_track_event? = true   # override in includers to gate
end
```

Then in `Card::Closeable#close`:

```ruby
def close(user: Current.user)
  transaction do
    not_now&.destroy
    create_closure!(user: user)
    track_event :closed, creator: user   # ← single line of audit
  end
end
```

### Why this scales

- One audit table, one schema, one notification pipeline
- Adding a new event type = add one `track_event` call; nothing else changes
- `particulars` JSON lets each action store custom metadata without schema churn
- Notifications, webhooks, system comments, and Turbo broadcasts all derive from Event — they're not coupled to each other
- The activity timeline is just `board.events.order(created_at: :desc)`

### When NOT to use Event

- Stats counters, last-touched timestamps — those are model columns
- Anything that should *not* show in an activity feed
- Anything happening more than once per second on a hot path (use a separate metric system)

---

## 9. Polymorphic Container for Cascading Config

When configuration should cascade down a hierarchy (account-level default, board-level override, etc.), don't duplicate columns. Use a polymorphic container.

```ruby
class Entropy < ApplicationRecord
  belongs_to :container, polymorphic: true   # Account or Board
  belongs_to :account
end

class Account < ApplicationRecord
  has_one :entropy, as: :container
end

class Board < ApplicationRecord
  has_one :entropy, as: :container
end
```

Then resolution cascades via SQL or Ruby:

```ruby
# In Card::Entropic
scope :due_to_be_postponed, -> {
  joins("LEFT OUTER JOIN entropies be ON be.container_type = 'Board' AND be.container_id = cards.board_id")
  .joins("LEFT OUTER JOIN entropies ae ON ae.container_type = 'Account' AND ae.container_id = cards.account_id")
  .where("cards.last_active_at <= NOW() - INTERVAL COALESCE(be.period_in_days, ae.period_in_days) DAY")
}
```

One concept, one table, polymorphic ownership, SQL `COALESCE` for cascade. Works for any "default at root, override at intermediate" config.

---

## 10. Sharded Denormalization

When you need full-text search at scale without adding Elasticsearch:

1. **Concern-driven sync**: `Searchable` concern with `after_*_commit` callbacks denormalizes records into a search table
2. **Dynamic shard classes**: a single class definition generates N subclasses at boot, each pointing at a different table (`search_records_0` through `search_records_15`)
3. **CRC32 hashing**: `shard_id = Zlib.crc32(account_id.to_s) % 16`, deterministic and uniform
4. **Read path filters at query time**: enforce access in the query, not the index

```ruby
class Search::Record < ApplicationRecord
  self.abstract_class = true

  16.times do |shard_id|
    const_set("Shard#{shard_id}", Class.new(self) { self.table_name = "search_records_#{shard_id}" })
  end

  def self.for(account_id)
    const_get("Shard#{Zlib.crc32(account_id.to_s) % 16}")
  end
end
```

Then `Search::Record.for(card.account_id).upsert!(...)` writes to the right shard.

Use this pattern when:
- You need indexed search across many tenants
- Tenants vary wildly in size
- You want isolated, parallelizable shards without separate databases
