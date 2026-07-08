# Core Rails composition patterns (1–7)

The everyday patterns for designing Rails domain models the vanilla-Rails / DHH way.
`SKILL.md` is the router — it summarizes each of these and points here for the full
treatment with code. The power-user patterns (Event audit trail, cascading config,
sharded search) live in [`advanced-patterns.md`](advanced-patterns.md) as #8–#10; N+1
prevention lives in [`performance-patterns.md`](performance-patterns.md).

Filenames in code comments are conventional locations, not load-bearing.

---

## 1. Aggregate Roots and Boundaries

Identify your aggregate roots first; they shape everything downstream. A root is a model that *owns* its dependents (cascades on destroy), can be queried independently, and represents a transaction boundary.

Typical SaaS shape:

- **Account** — the tenant. Owns boards, users, cards, tags, webhooks. Everything else is scoped beneath it.
- **Identity / User** — auth (global) vs membership (per-tenant). Don't conflate.
- **Board** — workflow canvas + access control boundary.
- **Card** — the rich work item; most behavior lives here via 20+ concerns.
- **Event** — *cross-cutting* immutable audit log; doesn't fit a single root.

### Heuristics

- **`has_many ..., dependent: :destroy` tells you ownership.** If destroying parent shouldn't destroy child, that child is probably its own root.
- **Thin models aren't anemic, they're focused.** A `Column`, `Closure`, `Tagging`, or `NotNow` model can be tiny — just a few columns, no methods — and still be the right design. Behavior lives where data is rich.
- **Cross-cutting concepts get their own root with polymorphic associations.** Event, Notification, Reaction. They reference any model that opts in via a concern.

### When to introduce a new model

You almost certainly need a new model (not a column, not an enum) when:
- The concept has its own lifecycle (created/destroyed independently)
- You want to track *who* and *when* for the state
- Multiple records of the concept can attach to one parent
- You want the concept to participate in joins (for scopes/queries)

This is the entry point to pattern #2.

---

## 2. State as a Resource (Routes and Records)

This is the single most important pattern to internalize. The CRUD-as-resources discipline says: **when an action doesn't fit standard CRUD, introduce a new resource — don't add a custom action.**

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

In parallel, model the state itself as a real table with `has_one`. For example:

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

A rich model can include 20+ concerns. The ordering is loose but follows a rough progression: state → relationships → queries → side effects.

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

- **Pure calculation, no AR hooks needed** → PORO in `app/models/card/some_calculation.rb` (a plain class, instantiate when needed).
- **The behavior is one method on one model** → just write the method. Concerns are for cohesion, not file-splitting.
- **You'd need to inject dependencies** → reach for a PORO or a job.

---

## 4. Thin Controllers, Rich Models

The rule: **one model method per controller action**. If a `create` action grows past 3-4 lines, the model is missing a method.

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

Side effects (notifications, broadcasts, webhooks) cascade automatically through the Event chain — see [`advanced-patterns.md`](advanced-patterns.md).

### Naming verbs

Good verbs are unfussy and domain-true: `gild`, `ungild`, `postpone`, `resume`, `close`, `reopen`, `triage_into(column)`, `send_back_to_triage`, `publish`, `pin_by(user)`, `unpin_by(user)`, `watch_by(user)`, `assign(user)`, `unassign(user)`.

Note the **lack of `!`** on most. Only use `!` when there's a non-bang counterpart with different semantics (the AR convention). Don't use `!` just to flag "destructive."

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
