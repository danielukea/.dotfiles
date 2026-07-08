---
name: rails-composition-dhh
description: DHH-style Rails composition patterns for domain models, controllers, and jobs. Use whenever designing, building, or reviewing Rails domain models, controllers, jobs, or cross-cutting infrastructure — especially when tempted to introduce a service object, custom controller action, state machine, or callback chain. Strongly invoke on any Rails 8 work involving aggregate design, has_many ownership, state transitions, async jobs, or how to factor behavior across models.
allowed-tools: Read, Grep, Glob
license: MIT
metadata:
  version: "1.1"
related_skills:
  - "frontend-design"
---

# DHH Rails Composition Patterns

Patterns for designing Rails domain models that stay maintainable as they grow, in the vanilla-Rails / DHH school: rich models, thin controllers, no service layer.

**This file is a router.** It states the core principle, catalogs the patterns with a one-line "what" and "when", and gives you the Decision Flow. Full treatments with code live in `references/` — open the linked section when you're at that decision point. You do not need to read everything at once.

## When to Use

Reach for this when:

- Designing a new Rails feature — before you reach for a service, form object, or state machine gem
- Reviewing a PR that introduces an abstraction "above" Active Record
- Adding behavior to an existing model and deciding *where* (concern? method? new model? job? callback?)
- Choosing between a custom controller action vs a new resource
- Adding async work and wondering how to shape the job class
- Encountering cross-cutting concerns like tenancy, audit logging, search, or notifications

Reference material — consult it at decision points; you don't need to apply every pattern at once.

## The Core Principle

**Vanilla Rails is plenty.** Active Record is not the constraint — it's the substrate. Rich domain behavior belongs on rich models, not in a service layer parallel to them. Controllers are thin orchestrators that scope, authorize, and dispatch a single intention-revealing method on the model.

Composition happens through:
1. **Active Record associations** that model real domain relationships
2. **Concerns** that bundle one cohesive behavior (associations + scopes + callbacks + methods)
3. **Real tables** for things that have identity (state markers, joins, value records)
4. **Polymorphism** when the same shape applies across the domain (events, reactions, search)

When you feel an itch for "Service / Form / Interactor / Operation / Use Case", first try: *can this be a model method, a concern, or a new resource?* In 90% of cases it can.

---

## Pattern Catalog

The seven core patterns. Each links to its full treatment (prose + code) in
[`references/core-patterns.md`](references/core-patterns.md). The three power-user patterns
(8–10) live in [`references/advanced-patterns.md`](references/advanced-patterns.md).

1. **[Aggregate Roots and Boundaries](references/core-patterns.md#1-aggregate-roots-and-boundaries)** — a root owns its dependents (`dependent: :destroy`), is queryable on its own, and is a transaction boundary. *Reach for it first* — roots shape everything downstream; identify them before modeling anything else.

2. **[State as a Resource](references/core-patterns.md#2-state-as-a-resource-routes-and-records)** — the most important pattern. When an action doesn't fit CRUD, introduce a *resource* (`resource :closure`), not a custom action — and model the state as a real `has_one` record, not a boolean/enum. *Reach for it* for any state transition (close/reopen, publish, postpone) or when tempted to add `post :close`.

3. **[Concerns](references/core-patterns.md#3-concerns-how-to-compose-behavior)** — the primary unit of composition. One concern = one cohesive behavior (associations + scopes + callbacks + methods). Namespaced (`Card::Closeable`) if model-specific, flat (`Searchable`) if shared. *Reach for it* when a cluster of related associations/scopes/methods belongs together.

4. **[Thin Controllers, Rich Models](references/core-patterns.md#4-thin-controllers-rich-models)** — one model method per controller action; authorization via query scoping (`Current.user.accessible_cards`), not policy objects; `params.expect`. *Reach for it* whenever a `create`/`update` action grows past 3–4 lines.

5. **[Intention-Revealing Model APIs](references/core-patterns.md#5-intention-revealing-model-apis)** — `card.close` contains the mutation, event, fan-out, and broadcast; callers don't reconstruct it. Unfussy domain verbs; no gratuitous `!`. *Reach for it* every time a controller or caller would otherwise assemble a multi-step mutation inline.

6. **[Callbacks vs Explicit Calls](references/core-patterns.md#6-callbacks-vs-explicit-calls)** — callbacks for *passive* side effects (timestamps, broadcasts, indexing); explicit methods for *state transitions a user means to do*. Use `after_create_commit` for anything that enqueues/broadcasts. *Reach for it* when deciding whether new behavior fires automatically or on an explicit call.

7. **[Jobs: `_later` / `_now`](references/core-patterns.md#7-jobs-the-_later--_now-pattern)** — shallow job classes; real work lives on the model. `_later` (private, callback-wired) enqueues; the job's `perform` is one line delegating back to the model. *Reach for it* for any async work; also covers job tenancy and recurring jobs.

Power-user patterns (open only when the situation calls for it):

8. **[Event as the universal audit trail](references/advanced-patterns.md#8-event-as-the-universal-audit-trail)** — one polymorphic `events` table drives notifications, webhooks, broadcasts, and the timeline without coupling them.
9. **[Polymorphic container for cascading config](references/advanced-patterns.md#9-polymorphic-container-for-cascading-config)** — account-default / board-override without duplicating columns.
10. **[Sharded denormalization](references/advanced-patterns.md#10-sharded-denormalization)** — full-text search at scale without Elasticsearch.

**Preloading & N+1:** prevention is structural — every list model defines `scope :preloaded` that controllers pipe collections through (no Bullet gem). Full convention in [`references/performance-patterns.md`](references/performance-patterns.md).

---

## Decision Flow: Where Does This Behavior Go?

When adding behavior, ask in this order:

1. **Is it a state transition with semantic meaning?**
   → New resource + controller + intention-revealing model method ([#2](references/core-patterns.md#2-state-as-a-resource-routes-and-records), [#5](references/core-patterns.md#5-intention-revealing-model-apis))
   → Track the state with a real record ([#2b](references/core-patterns.md#2b-state-as-a-real-record))

2. **Is it one cohesive cluster of associations/scopes/callbacks/methods?**
   → Concern ([#3](references/core-patterns.md#3-concerns-how-to-compose-behavior)). Nested under model namespace if specific; flat in `concerns/` if shared.

3. **Is it a one-method thing?**
   → Just write the method on the model. Don't over-abstract.

4. **Is it async work?**
   → `_later` on the model, one-line job class, `_now` on the model ([#7](references/core-patterns.md#7-jobs-the-_later--_now-pattern))

5. **Should it appear in an activity feed / drive notifications?**
   → Emit an Event via `track_event` ([#8](references/advanced-patterns.md#8-event-as-the-universal-audit-trail)). Don't write a parallel system.

6. **Is it cross-cutting (search, audit, mentions)?**
   → Shared concern + template-method hooks ([#3](references/core-patterns.md#3-concerns-how-to-compose-behavior))

7. **Is it stateless computation?**
   → PORO. Don't make it a concern just because it's logic.

8. **Does it have its own lifecycle, identity, or queryability?**
   → New model. Even if tiny ([#1](references/core-patterns.md#1-aggregate-roots-and-boundaries)).

### Things that almost never need to exist in a DHH codebase

- Service objects
- Form objects
- Interactor / Operation / UseCase / Command classes
- Policy objects (use scope + `before_action` predicates)
- Custom state machine DSL (use record-as-state)
- Decorator/presenter layer (use helpers or just `to_partial_path`)

If you reach for one of those, first try the patterns above. The full anti-patterns table — each abstraction, why it's wrong, and what to reach for instead — lives in [`references/style-guide.md`](references/style-guide.md#anti-patterns-dhh-avoids).

---

## Bundled References

- **[`references/core-patterns.md`](references/core-patterns.md)** — full treatment (prose + code) of the seven core patterns catalogued above. Open the section for the pattern you're applying.
- **[`references/style-guide.md`](references/style-guide.md)** — the style guide (with an appended [anti-patterns table](references/style-guide.md#anti-patterns-dhh-avoids)). Authoritative on: conditional returns (expanded conditionals vs guard clauses), method ordering, when (and when not) to use `!`, visibility-modifier indentation, CRUD controllers and the resource-over-action rule, controller↔model interaction philosophy, and async patterns.
- **[`references/advanced-patterns.md`](references/advanced-patterns.md)** — the power-user patterns #8–#10 (Event audit trail, polymorphic cascading config, sharded denormalization). Consult when a feature actually needs one.
- **[`references/performance-patterns.md`](references/performance-patterns.md)** — the `scope :preloaded` convention, `preload`/`includes`/`eager_load` distinctions, and the catalog of common N+1 traps.

---

*Source: [37signals' fizzy](https://github.com/basecamp/fizzy). Referenced filenames are conventional locations, not load-bearing.*
