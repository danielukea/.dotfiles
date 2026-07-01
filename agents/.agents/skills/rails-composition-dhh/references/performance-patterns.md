# Preloading & performance patterns

N+1 prevention in a DHH-style codebase is structural, not reactive — the discipline
lives in named scopes, not a Bullet-gem afterthought. Consult this when building list
views or diagnosing query bloat.

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
