---
name: rails
description: How Rails is written - trigger on any Ruby/Rails question: models, controllers, jobs, queries, service objects, where behavior belongs, version gotchas.
license: MIT
metadata:
  version: "2.0"
---

# Rails

How Rails is actually written. The framework's own conventions answer the question far more
often than they appear to, so the aim here is to write **less** — fewer classes, fewer
options, fewer layers.

**This file is a router.** It states the default, the precedence rule, and where behavior
goes. Worked code lives in `references/` — open the one matching what you're building.

## The Rails way

Rich models, thin controllers, no service layer. Behavior lives on the model that owns the
data. Controllers scope, authorize, and call one intention-revealing method. When an action
doesn't fit CRUD, introduce a **resource**, not a custom action.

Before adding any abstraction, try: **a model method, a concern, or a new resource.** That
is the answer roughly 90% of the time.

Rarely the right call — full table in [`style.md`](references/style.md):

- service objects · form objects · Interactor / Operation / UseCase / Command classes
- state-machine DSLs — use a real `has_one` state record
- a decorator or presenter layer added for its own sake

This is not a matter of taste. Measured across a production Rails 8 app of 102 controllers:
**1** non-CRUD action in the whole application, median controller **21 lines**, no
`app/services/` — full breakdown in
[`controllers-and-routes.md`](references/controllers-and-routes.md).

A controller past ~25 lines, or with an action outside the seven REST verbs, is the signal
to introduce a resource or move the behavior onto the model.

## Precedence

1. **The Rails way** (above) — the default for new code with no local precedent.
2. **The local convention** — when the file or subsystem you're editing already has an
   established pattern, or a project `AGENTS.md` / `.claude/rules` file states one, follow
   the codebase. Consistency within a subsystem beats purity.
3. **Don't refactor toward (1) as a side effect** of unrelated work. Note it and move on.

Expect real divergence, deliberately made. State modeling (`enum` vs a string column vs a
`has_one` record), authorization (query scoping vs a policy gem), and view-layer objects
(presenters, serializers) are where codebases most often differ on purpose. **Read the
local rules before assuming this skill wins.**

## Check the version first

`load_defaults` in `config/application.rb` — **not** the gem version — is the authority on
how the framework behaves. The two are bumped independently, so an app can run Rails 8 with
7.x semantics.

1. `config.load_defaults` in `config/application.rb`
2. the actual version in `Gemfile.lock`
3. `config/initializers/new_framework_defaults_*.rb` for partially-adopted flips

What flips at each version → [`references/versions.md`](references/versions.md).

## Where does this behavior go?

| The behavior…                                    | Goes                                        |
| ------------------------------------------------ | ------------------------------------------- |
| is a state transition with meaning               | a new resource + a real state record        |
| is one cohesive cluster of associations/methods  | a concern                                   |
| is one method                                    | write the method on the model. Stop there.  |
| is async                                         | `_later` on the model, one-line job         |
| has its own lifecycle, identity, or queryability | a new model, even a tiny one                |
| is stateless computation                         | a PORO. Not a concern.                      |
| is cross-cutting (audit, search, mentions)       | a shared concern with template-method hooks |

## Routing

| Working on                                  | Open                                                                        |
| ------------------------------------------- | --------------------------------------------------------------------------- |
| Domain boundaries, whether to add a model   | [`aggregates.md`](references/aggregates.md)                                 |
| A model — associations, validations, scopes | [`models.md`](references/models.md)                                         |
| Extracting shared behavior                  | [`concerns.md`](references/concerns.md)                                     |
| Controllers, routes, params, responses      | [`controllers-and-routes.md`](references/controllers-and-routes.md)         |
| Background jobs                             | [`jobs.md`](references/jobs.md)                                             |
| Views, partials, helpers, caching           | [`views-and-helpers.md`](references/views-and-helpers.md)                   |
| Mailers, Action Cable                       | [`mailers-and-channels.md`](references/mailers-and-channels.md)             |
| How code should read                        | [`style.md`](references/style.md)                                           |
| Queries, writes, N+1, races                 | [`active-record.md`](references/active-record.md)                           |
| Transactions, callbacks, commit timing      | [`transactions-and-callbacks.md`](references/transactions-and-callbacks.md) |
| Boot, autoloading, initializers             | [`boot-and-autoloading.md`](references/boot-and-autoloading.md)             |
| "Does API X exist in this Rails?"           | [`versions.md`](references/versions.md)                                     |
| Canonical documentation                     | [`sources.md`](references/sources.md)                                       |

## Gotchas

**Append new failure modes here as you hit them.** Each line is a hook — follow the pointer
for the detail.

- **Whether enqueuing a job inside a transaction is safe depends on the queue backend** — a
  database-backed queue is transactional, a Redis-backed one races, and a codebase
  mid-migration has both — see `transactions-and-callbacks.md`.
- **`return`/`break` out of a `transaction do` block commits** as of Rails 8.0. Only a raise
  (or `ActiveRecord::Rollback`) rolls back — see `transactions-and-callbacks.md`.
- **Association options Rails already infers are noise** — and `class_name:`/`foreign_key:`
  are inferred from _different_ things, so overriding one doesn't oblige the other — see
  `models.md`.
- **`enum status: [...]` (keyword form) was removed in Rails 8.0.** Only
  `enum :status, [...]` parses — see `versions.md`.
- **Don't trust a remembered feature→version mapping.** `normalizes`, `generates_token_for`,
  `rate_limit`, and `where.missing` are 6.x/7.x, not 8.x. Check a version-pinned guide URL —
  see `sources.md`.
- **`update_all` / `delete_all` / `insert_all` / `update_column` skip callbacks, validations,
  and `updated_at`**; `delete_all` also ignores `dependent:` — see `active-record.md`.
- **`pluck` and `count` re-query even when the relation is already loaded.** On a loaded
  collection use `map(&:id)` and `count { … }` — see `active-record.md`.
- **`saved_change_to_*` is unreliable in `after_*_commit`** — capture a flag in
  `before_update` instead — see `transactions-and-callbacks.md`.
- **Rescuing an exception inside a transaction leaves Postgres in an aborted state**, so
  every later statement fails far from the real cause — see `transactions-and-callbacks.md`.
- **Identically-named transaction callbacks are deduplicated** — only the last survives
  unless distinguished by `on:` — see `transactions-and-callbacks.md`.
- **Initializers run in alphabetical order.** Never rely on another having run;
  `require_relative` it — see `boot-and-autoloading.md`.

## Not in this skill

Migrations → `strong-migrations` · specs → `test-principles` · auth, sessions, injection →
`security-principles` · the ActiveAdmin DSL → `active-admin` · React → `react-composition`
