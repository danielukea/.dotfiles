---
name: rails-composition-dhh
description: DHH/37signals Rails composition patterns extracted from the fizzy codebase. Use whenever designing, building, or reviewing Rails domain models, controllers, jobs, or cross-cutting infrastructure — especially when tempted to introduce a service object, custom controller action, state machine, or callback chain. Strongly invoke on any Rails 8 work involving aggregate design, has_many ownership, state transitions, async jobs, or how to factor behavior across models.
context: fork
allowed-tools: Read, Grep, Glob
license: MIT
metadata:
  author: extracted from 37signals/fizzy
  version: "1.0"
related_skills:
  - "frontend-design"
---

# DHH / 37signals Rails Composition Patterns

Patterns mined from the fizzy codebase (37signals' kanban tool) for designing Rails domain models that stay maintainable as they grow. These aren't theoretical — every pattern below is observable in `app/models`, `app/controllers`, and `config/routes.rb` of a production DHH-authored codebase.

## Table of Contents

- [When to Use](#when-to-use)
- [The Core Principle](#the-core-principle)
- [1. Aggregate Roots and Boundaries](#1-aggregate-roots-and-boundaries)
- [2. State as a Resource (Routes and Records)](#2-state-as-a-resource-routes-and-records)
- [3. Concerns: How to Compose Behavior](#3-concerns-how-to-compose-behavior)
- [4. Thin Controllers, Rich Models](#4-thin-controllers-rich-models)
- [5. Intention-Revealing Model APIs](#5-intention-revealing-model-apis)
- [6. Callbacks vs Explicit Calls](#6-callbacks-vs-explicit-calls)
- [7. Jobs: The `_later` / `_now` Pattern](#7-jobs-the-_later--_now-pattern)
- [8. Event as the Universal Audit Trail](#8-event-as-the-universal-audit-trail)
- [9. Polymorphic Container for Cascading Config](#9-polymorphic-container-for-cascading-config)
- [10. Sharded Denormalization](#10-sharded-denormalization)
- [11. Decision Flow: Where Does This Behavior Go?](#11-decision-flow-where-does-this-behavior-go)
- [12. Anti-Patterns DHH Avoids](#12-anti-patterns-dhh-avoids)
- [13. Preloading: The `scope :preloaded` Convention](#13-preloading-the-scope-preloaded-convention)
- [Source Citations](#source-citations)
- [Bundled References](#bundled-references)

## When to Use

Apply these patterns when:

- Designing a new Rails feature — before you reach for a service, form object, or state machine gem
- Reviewing a PR that introduces an abstraction "above" Active Record
- Adding behavior to an existing model and deciding *where* (concern? method? new model? job? callback?)
- Choosing between a custom controller action vs a new resource
- Adding async work and wondering how to shape the job class
- Encountering cross-cutting concerns like tenancy, audit logging, search, or notifications

This skill is reference material. Consult it at decision points; you don't need to apply every pattern at once.

## The Core Principle

**Vanilla Rails is plenty.** Active Record is not the constraint — it's the substrate. Rich domain behavior belongs on rich models, not in a service layer parallel to them. Controllers are thin orchestrators that scope, authorize, and dispatch a single intention-revealing method on the model.

Composition happens through:
1. **Active Record associations** that model real domain relationships
2. **Concerns** that bundle one cohesive behavior (associations + scopes + callbacks + methods)
3. **Real tables** for things that have identity (state markers, joins, value records)
4. **Polymorphism** when the same shape applies across the domain (events, reactions, search)

When you feel an itch for "Service / Form / Interactor / Operation / Use Case", first try: *can this be a model method, a concern, or a new resource?* In 90% of cases it can.

---

## 1. Aggregate Roots and Boundaries

Identify your aggregate roots first; they shape everything downstream. A root is a model that *owns* its dependents (cascades on destroy), can be queried independently, and represents a transaction boundary.

Typical SaaS shape (from fizzy):

- **Account** — the tenant. Owns boards, users, cards, tags, webhooks. Everything else is scoped beneath it.
- **Identity / User** — auth (global) vs membership (per-tenant). Don't conflate.
- **Board** — workflow canvas + access control boundary.
- **Card** — the rich work item; most behavior lives here via 20+ concerns.
- **Event** — *cross-cutting* immutable audit log; doesn't fit a single root.

### Heuristics

- **`has_many ..., dependent: :destroy` tells you ownership.** If destroying parent shouldn't destroy child, that child is probably its own root.
- **Thin models aren't anemic, they're focused.** A `Column`, `Closure`, `Tagging`, or `NotNow` model can be tiny — just a few columns, no methods — and still be the right design. Behavior lives where data is rich.
- **Cross-cutting concepts get their own root with polymorphic associations.** Event, Notification, Reaction in fizzy. They reference any model that opts in via a concern.

### When to introduce a new model

You almost certainly need a new model (not a column, not an enum) when:
- The concept has its own lifecycle (created/destroyed independently)
- You want to track *who* and *when* for the state
- Multiple records of the concept can attach to one parent
- You want the concept to participate in joins (for scopes/queries)

This is the entry point to pattern #2.

---

## 2. State as a Resource (Routes and Records)

This is the single most important pattern to internalize. DHH's CRUD-as-resources discipline (codified in fizzy's `STYLE.md`) says: **when an action doesn't fit standard CRUD, introduce a new resource — don't add a custom action.**

There are *two* layers to it: routes AND data.

### 2a. State as a route resource

**Avoid:**
```ruby
resources :cards do
  post :close
  post :reopen
  post :gild
  post :ungild
  post :postpone
end
```

**Prefer:**
```ruby
resources :cards do
  resource :closure      # POST creates → close; DELETE → reopen
  resource :goldness     # POST → gild; DELETE → ungild
  resource :not_now      # POST → postpone
  resource :triage       # POST → triage_into(column); DELETE → send back
  resource :pin
  resource :watch
  resource :publish
end
```

Each becomes its own controller (`Cards::ClosuresController`, `Cards::GoldnessesController`, etc.) with `create` and `destroy` actions. `POST` means "transition forward", `DELETE` means "transition back".

Benefits:
- Each controller has one clear responsibility
- Authorization, params, and broadcasts stay tightly scoped to one transition
- Routes scale linearly with new states
- `Cards::ClosuresController#create` is more readable than `CardsController#close`

### 2b. State as a real record

In parallel, model the state itself as a real table with `has_one`. From fizzy:

- `Card::Closure` — when present, the card is closed. Records `closed_by` and `closed_at`.
- `Card::NotNow` — when present, the card is postponed. Records who postponed and when.
- `Card::Goldness` — when present, the card is "golden" (favorited).
- `Board::Publication` — when present, the board is published publicly (holds the shareable key).

Why a record instead of a boolean column or enum:

- **Tracks who/when for free** — no extra columns on the parent
- **Enables joins for scopes** — `Card.postponed` joins `card_not_nows`; `Card.closed` joins `card_closures`
- **Makes operations idempotent** — `close` is `create_closure! unless closed?`
- **Lets you destroy to reverse** — `reopen` is `closure&.destroy`
- **Composes with other state** — you can be both watched and assigned without column proliferation
- **Avoids the enum-state-machine trap** — multiple concurrent states (closed AND watched AND assigned) just work

```ruby
# app/models/card/closeable.rb
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, class_name: "Card::Closure", dependent: :destroy
    scope :closed, -> { joins(:closure) }
    scope :open,   -> { where.missing(:closure) }
  end

  def closed? = closure.present?

  def close(user: Current.user)
    transaction do
      not_now&.destroy
      create_closure!(user: user)
      track_event :closed, creator: user
    end
  end

  def reopen(user: Current.user)
    transaction do
      closure.destroy
      track_event :reopened, creator: user
    end
  end
end
```

---

## 3. Concerns: How to Compose Behavior

Concerns are the primary unit of composition. Get this right and your models stay readable even when they grow to 20+ behaviors.

### Two locations, two meanings

- **`app/models/concerns/foo.rb`** — shared across multiple models. Examples: `Searchable`, `Eventable`, `Notifiable`, `Mentions`, `Attachments`. Naming is the bare adjective/role.
- **`app/models/card/foo.rb`** (or `board/`, `account/`, etc.) — behavior specific to that one model. Examples: `Card::Postponable`, `Card::Closeable`, `Board::Publishable`, `Account::Entropic`. Namespace tells you "this is meaningless on other models."

A nested concern can include the shared one and extend it: `Card::Eventable includes ::Eventable, then overrides should_track_event?`. That's the template-method polymorphism pattern (more below).

### Anatomy of a concern

Each concern owns *one cohesive behavior*. Typical anatomy:

```ruby
module Card::Postponable
  extend ActiveSupport::Concern

  included do
    has_one :not_now, class_name: "Card::NotNow", dependent: :destroy
    scope :postponed, -> { joins(:not_now) }
    scope :active,    -> { where.missing(:not_now) }
  end

  def postponed? = not_now.present?

  def postpone(user: Current.user, event_name: :postponed)
    transaction do
      send_back_to_triage(skip_event: true)
      reopen
      activity_spike&.destroy
      create_not_now!(user: user) unless postponed?
      track_event event_name, creator: user
    end
  end

  def auto_postpone(user:)
    postpone(user: user, event_name: :auto_postponed)
  end

  def resume(user: Current.user)
    transaction do
      not_now&.destroy
      activity_spike&.destroy
      track_event :resumed, creator: user
    end
  end
end
```

It bundles: an association, two scopes, a predicate, and the state-transition methods. *Everything related to postponement lives here.* The Card model just `include Card::Postponable`.

### Composing many concerns on a fat model

Fizzy's `Card` includes ~24 concerns. The ordering is loose but follows a rough progression: state → relationships → queries → side effects.

```ruby
class Card < ApplicationRecord
  include Accessible, Assignable, Attachments, Broadcastable,
          Closeable, Colored, Commentable, Entropic, Eventable,
          Exportable, Golden, Mentions, Multistep, Pinnable,
          Postponable, Promptable, Readable, Searchable, Stallable,
          Statuses, Storage::Tracked, Taggable, Triageable, Watchable
end
```

When the include list gets long, that's a feature — it's the *table of contents* for the model. You read it to know what this model does, then open the relevant concern when you need detail.

### Template-method polymorphism

Shared concerns expose hooks for includers to override:

```ruby
# app/models/concerns/searchable.rb
module Searchable
  extend ActiveSupport::Concern

  included do
    after_create_commit  :index_for_search
    after_update_commit  :update_search_index
    after_destroy_commit :remove_from_search_index
  end

  def searchable?  = raise NotImplementedError
  def search_title = raise NotImplementedError
  # ...
end

# app/models/card/searchable.rb
module Card::Searchable
  include ::Searchable

  def searchable?  = published? && !closed?
  def search_title = title
  def search_content = description.to_plain_text
end
```

The shared concern owns the *lifecycle*; the model-specific one owns the *content*.

### When NOT to use a concern

- **Pure calculation, no AR hooks needed** → PORO in `app/models/card/some_calculation.rb` (a plain class, instantiate when needed). Fizzy's `Event::Description` works this way.
- **The behavior is one method on one model** → just write the method. Concerns are for cohesion, not file-splitting.
- **You'd need to inject dependencies** → reach for a PORO or a job.

---

## 4. Thin Controllers, Rich Models

The fizzy rule: **one model method per controller action**. If a `create` action grows past 3-4 lines, the model is missing a method.

```ruby
# Good — controllers stay thin
class Cards::GoldnessesController < ApplicationController
  include CardScoped

  def create
    @card.gild
  end

  def destroy
    @card.ungild
  end
end

class Cards::TriagesController < ApplicationController
  include CardScoped

  def create
    column = @board.columns.find(params[:column_id])
    @card.triage_into(column)
  end
end
```

### The scoping-concern pattern

Authorization + parent lookup gets factored into controller concerns:

```ruby
# app/controllers/concerns/card_scoped.rb
module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_card, :set_board
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    end

    def set_board
      @board = @card.board
    end
end
```

Note the authorization-via-scope trick: `Current.user.accessible_cards.find_by!` enforces access by *scoping the query*. If the user can't access the card, it raises `RecordNotFound` → 404. No CanCan, no Pundit, no policy objects.

For role checks beyond scope, use explicit `before_action` predicates:

```ruby
before_action :ensure_permission_to_admin_board, only: %i[update destroy]

private
  def ensure_permission_to_admin_board
    head :forbidden unless Current.user.can_administer_board?(@board)
  end
```

### Strong params: `wrap_parameters` + `params.expect`

```ruby
class CardsController < ApplicationController
  wrap_parameters :card, include: %i[title description image created_at last_active_at]

  def create
    @card = @board.cards.create!(card_params.merge(creator: Current.user))
  end

  private
    def card_params
      params.expect(card: [:title, :description, :image, :created_at, :last_active_at])
    end
end
```

- `wrap_parameters` makes the same controller handle JSON clients and Turbo forms with one params shape
- `params.expect` (Rails 8) is stricter than `require`/`permit` — it raises on unexpected keys, surfacing API drift early
- The whitelist is *documentation* of what the endpoint accepts

### Error handling: two layers

```ruby
def update
  @board.update!(entropy_params)
  respond_to do |format|
    format.turbo_stream
    format.json { render "boards/show", status: :ok }
  end
rescue ActiveRecord::RecordInvalid
  head :unprocessable_entity
end
```

Authorization in `before_action` (returns 403/404 early). Validation errors rescued in the action (`head :unprocessable_entity`). No exception classes you wrote yourself — lean on Rails' built-ins.

---

## 5. Intention-Revealing Model APIs

Names matter. Compare:

```ruby
# Anemic — caller has to know the implementation
card.update!(closed_at: Time.current, closed_by: Current.user)
Notification.create!(user: user, ...) for watcher in card.watchers
WebhookDispatch.new(:card_closed, card).call
```

```ruby
# Intention-revealing
card.close
```

The model method `close` *contains* the state mutation, the event emission, the notification fan-out, and the broadcast. Callers don't reconstruct that every time.

A well-written model method:

1. Opens a `transaction` if multi-step
2. Mutates the linked records (creates a Closure, destroys NotNow, etc.)
3. Calls `track_event :closed, ...` to emit the audit record
4. Returns the relevant new state (the closure record, true/false, etc.)

Side effects (notifications, broadcasts, webhooks) cascade automatically through the Event chain — see pattern #8.

### Naming verbs

Fizzy's verbs are unfussy and domain-true: `gild`, `ungild`, `postpone`, `resume`, `close`, `reopen`, `triage_into(column)`, `send_back_to_triage`, `publish`, `pin_by(user)`, `unpin_by(user)`, `watch_by(user)`, `assign(user)`, `unassign(user)`.

Note the **lack of `!`** on most. Per fizzy's style guide: only use `!` when there's a non-bang counterpart with different semantics (the AR convention). Don't use `!` just to flag "destructive."

---

## 6. Callbacks vs Explicit Calls

The most subtle pattern: **callbacks are for passive side effects, explicit methods are for state transitions.**

### Use callbacks for:

- Touching parent activity timestamps
- Broadcasting Turbo Stream updates (`broadcasts_refreshes`)
- Enqueuing notification jobs after a record is created
- Auto-subscribing/watching when a related action happens
- Indexing for search (the `Searchable` lifecycle)

```ruby
# Comment auto-watches the card
class Comment < ApplicationRecord
  after_create_commit :watch_card_by_creator

  private
    def watch_card_by_creator
      card.watch_by(creator)
    end
end
```

### Use explicit methods for:

- Closing, reopening, postponing, publishing — anything a user *means to do*
- Multi-step transitions that need a transaction
- Anything that should emit an Event with semantic meaning

Never trigger `card.close` from a callback. The controller calls `card.close` directly. The model method does the work.

### `after_create_commit`, not `after_create`

For anything that enqueues a job or broadcasts: commit first, then fire. Jobs that deserialize the record before the transaction commits will fail.

```ruby
after_create_commit :notify_recipients_later   # ✓ transaction has committed
after_create        :track_internal_metric     # ✓ in-transaction is fine for AR-only work
```

### Conditional callbacks

Guard with `previously_changed` to avoid no-op work:

```ruby
after_save_commit :push_later, if: -> { source_id_previously_changed? }
```

---

## 7. Jobs: The `_later` / `_now` Pattern

Shallow job classes. Real work lives on the model.

```ruby
# app/models/concerns/notifiable.rb
module Notifiable
  extend ActiveSupport::Concern

  included do
    after_create_commit :notify_recipients_later
  end

  def notify_recipients          # ← public; called by the job
    Notifier.for(self)&.notify
  end

  private
    def notify_recipients_later  # ← private; only triggered by the callback
      NotifyRecipientsJob.perform_later(self)
    end
end

# app/jobs/notify_recipients_job.rb
class NotifyRecipientsJob < ApplicationJob
  def perform(notifiable)
    notifiable.notify_recipients  # ← delegates straight back to the model
  end
end
```

Rules:

- The `_later` method is **private** — it's wired to a callback, never called directly
- The job's `perform` is one line: `record.foo` (or `record.foo_now` only when a meaningful sync/async pair exists)
- The `_now` suffix is not universal — only use it when there's an explicit non-async counterpart with different semantics
- All actual work lives on the model; the job is purely the async transport layer

### Why this shape

- Job class is trivially testable (and testable means almost never broken)
- The work is testable as a regular model method
- Stack traces stay on the model where humans expect them
- Easy to call `foo_now` directly in tests or scripts

### Tenancy in jobs

Use a single concern prepended to `ApplicationJob` that captures `Current.account` at enqueue and restores it on perform:

```ruby
# app/jobs/concerns/account_tenanted.rb (prepended in ApplicationJob)
module AccountTenanted
  def initialize(*args)
    super
    @account = Current.account
  end

  def serialize
    super.merge("account" => @account&.to_gid)
  end

  def deserialize(job_data)
    super
    @account_gid = job_data["account"]
  end

  def perform_now
    Current.with_account(GlobalID::Locator.locate(@account_gid)) { super }
  end
end
```

This eliminates manual account-passing across every job.

### Recurring jobs

Use `config/recurring.yml` (Solid Queue) and call *model class methods*, not job-specific logic:

```yaml
auto_postpone_all_due:
  class: "Card"
  command: "Card.auto_postpone_all_due"
  schedule: "every hour at minute 50"
```

The class method (`Card.auto_postpone_all_due`) iterates due records and calls `card.auto_postpone` on each. Logic stays in the domain model.

---

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

---

## 11. Decision Flow: Where Does This Behavior Go?

When adding behavior, ask in this order:

1. **Is it a state transition with semantic meaning?**
   → New resource + controller (#2a) + intention-revealing model method (#5)
   → Track the state with a real record (#2b)

2. **Is it one cohesive cluster of associations/scopes/callbacks/methods?**
   → Concern (#3). Nested under model namespace if specific; flat in `concerns/` if shared.

3. **Is it a one-method thing?**
   → Just write the method on the model. Don't over-abstract.

4. **Is it async work?**
   → `_later` on the model, one-line job class, `_now` on the model (#7)

5. **Should it appear in an activity feed / drive notifications?**
   → Emit an Event via `track_event` (#8). Don't write a parallel system.

6. **Is it cross-cutting (search, audit, mentions)?**
   → Shared concern + template-method hooks (#3, end)

7. **Is it stateless computation?**
   → PORO. Don't make it a concern just because it's logic.

8. **Does it have its own lifecycle, identity, or queryability?**
   → New model. Even if tiny.

**Things that almost never need to exist in a DHH codebase:**

- Service objects
- Form objects
- Interactor / Operation / UseCase / Command classes
- Policy objects (use scope + `before_action` predicates)
- Custom state machine DSL (use record-as-state)
- Decorator/presenter layer (use helpers or just `to_partial_path`)

If you reach for one of those, first try the patterns above.

---

## 12. Anti-Patterns DHH Avoids

| Anti-pattern | Why it's wrong | What to do instead |
|--------------|----------------|---------------------|
| Service object as default | Hides domain logic from the model that owns the data; creates a parallel API surface | Model method, named for the intent (#5) |
| Custom controller action (`post :close`) | Mixes mutation verbs into resource controllers; doesn't scale | Introduce a new resource (#2a) |
| Enum + state machine for status | Forces single-axis state; doesn't track who/when; hard to combine with other states | Real `has_one` state record (#2b) |
| Fat job classes | Untestable, code split between job and model | `_later` enqueues, job delegates to model `_now` (#7) |
| `default_scope` for tenancy | Surprises in console, joins, raw SQL; hard to undo | URL-based slug + `Current.account` + `belongs_to default: -> { ... }` |
| Callbacks for state transitions | Magic, hard to follow, easy to trigger accidentally | Explicit method on the model; callbacks for passive effects only (#6) |
| Form objects to validate combinations | Splits validation between form and model | Validations on the model; presenter/decorator only if truly view-only |
| Pundit/CanCan policy objects | Adds a layer for what scoping already enforces | Scope queries through `Current.user.accessible_*`; explicit `ensure_*` predicates |
| Guard clauses everywhere | Hard to read with nesting | Expanded conditionals; reserve guards for early-method returns with non-trivial bodies (per fizzy `STYLE.md`) |
| `!` to mark "destructive" | Misleading; `!` in Ruby means "raises" or "has a counterpart" | Drop the `!` unless there's a non-bang variant |
| No `scope :preloaded` on list models | Each view partial fires 1+ queries per row (classic N+1) | Define `scope :preloaded` on the model; pipe all list queries through it (#13) |
| `.count` on a scope chained over preloaded data | Rails fires a new COUNT query even though records are in memory | Use `collection.count { \|r\| r.condition? }` to count in Ruby on already-loaded records |

---

## 13. Preloading: The `scope :preloaded` Convention

Every model rendered in a list defines a named `scope :preloaded` that controllers pipe collections through before passing to views. N+1 prevention is structural, not reactive — there is no Bullet gem; the discipline lives in the scopes.

### The pattern

```ruby
# app/models/card.rb
scope :with_users, -> {
  preload(creator: [:avatar_attachment, :account],
          assignees: [:avatar_attachment, :account])
}
scope :preloaded, -> {
  with_users
    .preload(:column, :tags, :steps, :closure, :goldness,
             :activity_spike, :image_attachment,
             reactions: :reacter,
             board: [:entropy, :columns],
             not_now: [:user])
    .with_rich_text_description_and_embeds
}
```

Then in every list controller:

```ruby
@cards = @board.cards.active.preloaded
```

Other models follow the same convention:

```ruby
# app/models/notification.rb
scope :preloaded, -> {
  preload(:creator, :account,
          card: [:board, :column, :closure, :not_now],
          source: [:board, :creator, { eventable: [:closure, :board, :assignments] }])
}

# app/models/event.rb
scope :preloaded, -> {
  includes(:creator, :board,
           { eventable: [:creator, :goldness, :closure, :image_attachment,
                         { card: [:goldness, :closure] }] })
}

# app/models/comment.rb
scope :preloaded, -> { with_rich_text_body.includes(reactions: :reacter) }
```

### `preload` vs `includes` vs `eager_load`

- **`preload`** — always fires separate queries, never JOINs. Preferred inside `preloaded` scopes. Predictable; can't accidentally generate a Cartesian product.
- **`includes`** — Rails chooses `preload` or `eager_load` based on whether other clauses reference the association. Use when callers might chain `.where(...)` on the included table (e.g., `Event.preloaded` uses `includes` for this reason).
- **`eager_load`** — forces a single LEFT OUTER JOIN. Avoid unless you explicitly need to filter or sort on the associated table in SQL.

### Composing sub-scopes

When a cluster of associations belong together, extract into a named sub-scope so controllers can load just that subset when needed:

```ruby
scope :with_users, -> {
  preload(creator: [:avatar_attachment, :account],
          assignees: [:avatar_attachment, :account])
}
scope :preloaded, -> { with_users.preload(:column, :tags, ...) }
```

### Controller-level supplements

When the named scope is insufficient for a specific action, controllers add `.includes()` directly:

```ruby
# boards_controller.rb — board list needs creator identity
@boards = Current.user.boards.includes(creator: :identity)

# my/pins_controller.rb — pins don't define preloaded
@pins = Current.user.pins.includes(:card)
```

### Fragment caching as a second line of defense

Pair `preloaded` with `cached: true` on collection renders:

```erb
<%# cards/display/_previews.html.erb %>
<%= render partial: "cards/display/preview", collection: @cards, cached: true %>
```

The cache means a cold N+1 hits once per record, not once per request. Don't rely on caching to paper over missing preloads — fix the scope first, then cache.

### Common N+1 traps

**Calling `.count` on a chained scope over a preloaded association**

```ruby
# Bad — fires a COUNT query per card even though steps are already loaded
card.steps.completed.count

# Good — count in Ruby on the already-loaded records
card.steps.count { |s| s.completed? }
```

**Accessing associations not in `preloaded` from list partials**

Comments are not in `Card.preloaded` — accessing them in a card preview partial fires a query per card. Only access comment associations on the card show page where they're loaded separately.

**Missing counter cache for per-row counts**

`column.cards.active.count` in a columns list fires a COUNT per column with no counter cache. Add a counter cache or denormalize the count onto the column model.

**Polymorphic preload gaps**

When a polymorphic `source_type` resolves to a type whose own sub-associations you haven't included, traversing those associations fires extra queries. Audit every `source_type` variant in your `preloaded` scope.

**`user.account` unloaded in avatar helpers**

The avatar helper accesses `user.account.slug`. Safe when loaded via `with_users` (which preloads `:account`), but controllers that use only `includes(:identity)` leave `:account` unpreloaded and trigger a query per avatar rendered.

---

## Pattern Provenance

Every pattern in this skill was extracted from a real production Rails codebase: **37signals' fizzy** — a DHH-authored kanban tool, open-source at **https://github.com/basecamp/fizzy**. When a pattern below references a filename, you can grep it directly in that repo to see the production implementation.

The filenames are *pattern references* — when working in a similarly-styled codebase, look for analogous files. If the codebase doesn't yet have them, these names are the conventional places to put them.

- **Aggregates**: `app/models/{account,board,card,event,identity,user}.rb`
- **State-as-resource controllers**: `app/controllers/cards/{closures,goldnesses,not_nows,triages,pins,watches,publishes}_controller.rb`; routed in `config/routes.rb`
- **State-as-record concerns**: `app/models/card/{closeable,postponable,golden,watchable,pinnable}.rb` paired with matching state records (`app/models/{closure,card/not_now,card/goldness}.rb`)
- **Shared concerns**: `app/models/concerns/{eventable,searchable,notifiable,mentions,attachments}.rb`
- **Controller scoping**: `app/controllers/concerns/{card_scoped,board_scoped,column_scoped,authorization}.rb`
- **Jobs and tenancy**: `app/jobs/*.rb`; `app/jobs/concerns/account_tenanted.rb`; `config/recurring.yml`
- **Event chain**: `app/models/event.rb`; `app/models/event/particulars.rb`
- **Polymorphic container**: `app/models/entropy.rb` paired with `app/models/{account,board,card}/entropic.rb`
- **Sharded denormalized search**: `app/models/search/record.rb`; `app/models/search/record/trilogy.rb`
- **Style guide**: bundled in this skill at [`references/style-guide.md`](references/style-guide.md) — the source of truth for conditionals, method ordering, `!`-naming, controller/model interaction, and async patterns.

The skill is self-contained — everything you need to apply these patterns is in `SKILL.md` and `references/style-guide.md`. You do not need access to the original codebase. When applying to a new project, the patterns transfer; the file *names* are conventional but not load-bearing.

---

## Bundled References

- **[`references/style-guide.md`](references/style-guide.md)** — a verbatim copy of fizzy's `STYLE.md`. Read this when you need authoritative guidance on:
  - Conditional returns (expanded conditionals vs guard clauses)
  - Method ordering (class → public → private; vertical invocation order)
  - When (and when not) to use `!` on method names
  - Visibility modifier indentation
  - CRUD controllers and the resource-over-action rule
  - Controller↔model interaction philosophy (vanilla Rails, no service objects by default)
  - Async operation patterns (`_later` / `_now`)

  When reviewing or designing Rails code, consult this file directly — the SKILL.md above generalizes from it but the original prose is shorter, sharper, and worth quoting.

