---
name: strong-migrations
description: Use whenever creating, writing, editing, reviewing, or verifying a Rails database migration — including the everyday `rails generate migration` / add-column case, not just dangerous ones. Covers generator naming conventions, zero-downtime safety, expand/contract, strong_migrations verification, and the safe sequence for operations on an existing table/column (remove/rename/retype, add constraints, add an index, backfill). Trigger even for a plain "add a column" migration. Not for extracting migrations into a stacked PR (`extract-migrations`) or syncing the local DB (`sprout-sync`).
---

# Rails Migrations, Safe for Rolling Deploys

Migrations ship into a **rolling deploy**: old and new application code run at the same time during the
rollout. So the governing rule is — **every migration must leave the schema compatible with the code
running *before* the deploy.** Most migrations (creating a table, adding a nullable column) satisfy this
trivially. The dangerous ones touch existing production columns or tables, and each has a known safe
sequence.

## Why some migrations are dangerous

Two independent failure modes cause downtime:

1. **App/schema mismatch.** Old code expects the old schema. Worse, ActiveRecord caches the full column
   list at boot and writes *every* column into each INSERT/UPDATE — so dropping a column crashes code
   that never even names it.
2. **Lock-queue head-of-line blocking.** Many DDL operations take an `ACCESS EXCLUSIVE` lock that
   conflicts with everything, including plain SELECTs. A DDL request that can't get the lock immediately
   queues — and every later query on that table queues behind it. One slow query + one DDL = the table
   looks frozen. Set `lock_timeout` so DDL aborts fast instead of forming a kill queue.

## Which operations need care

If your migration isn't in this table, it's almost certainly safe as generated. If it is, read the
linked section of `references/safe-sequences.md` for the full worked sequence.

| Operation | The trap | Safe approach | Section |
|-----------|----------|---------------|---------|
| Remove a column | AR caches columns; old code crashes | `ignored_columns` → deploy → then drop | [Removing a Column](references/safe-sequences.md#removing-a-column) |
| Rename a column | Old code writes the old name → data loss | Expand/contract, 3 deploys | [Renaming a Column](references/safe-sequences.md#renaming-a-column) |
| Rename a table | Old code references old name → errors | Expand/contract, 3 deploys | [Renaming a Table](references/safe-sequences.md#renaming-a-table) |
| Change a column type | Table rewrite, full lock | Add new col → backfill → switch → drop old | [Changing Column Type](references/safe-sequences.md#changing-column-type) |
| Add column w/ non-null default | Table rewrite (PG < 11; volatile defaults always) | Add nullable → backfill → add NOT NULL | [Adding a Column with a Non-Null Default](references/safe-sequences.md#adding-a-column-with-a-non-null-default) |
| Set NOT NULL on existing column | Locks during full-table validation | Check constraint NOT VALID → validate → convert | [Setting NOT NULL](references/safe-sequences.md#setting-not-null-on-an-existing-column) |
| Add an index | Blocks writes for the whole build | `algorithm: :concurrently` + `disable_ddl_transaction!` | [Adding an Index](references/safe-sequences.md#adding-an-index) |
| Add a foreign key | `ACCESS EXCLUSIVE` on both tables | `validate: false` → validate separately | [Adding a Foreign Key](references/safe-sequences.md#adding-a-foreign-key) |
| Add a check constraint | Locks during the row scan | `validate: false` → validate separately | [Adding a Check Constraint](references/safe-sequences.md#adding-a-check-constraint) |
| Backfill data | Long transaction holds a lock | `disable_ddl_transaction!` + `in_batches` | [Backfilling Data](references/safe-sequences.md#backfilling-data) |

Common thread: **do the expensive work without a blocking lock, and split anything that changes what
old code sees across multiple deploys.**

## Creating a migration

Reach for the generator — the name is parsed into the body:

```bash
bin/rails generate migration AddPreferencesToUsers preferences:jsonb
```

Handy name patterns: `CreateProducts name:string`, `AddXToTable field:type`, `RemoveXFromTable
field:type`, `field:string:index` (adds an index), `field:string!` (`null: false`). For the full
name-parsing rules, the `change`/`up`/`down`/reversibility API, and `disable_ddl_transaction!`, see
`references/generator.md`. Heads-up: don't add an indexed reference with `add_reference` on a live
table (non-concurrent index + validated FK, both blocking) — split it, per the Adding an Index section.

## Know your project's conventions

What counts as "safe" is partly project-specific. If a safe-looking operation is unexpectedly rejected,
check `config/initializers/strong_migrations.rb` and any custom `ActiveRecord::Migration` overrides or
generators — projects customize behavior (e.g. banning `add_reference`, auto-applying `:concurrently`,
routing data changes through a separate data-migration generator).

## Verifying

If the project uses [strong_migrations](https://github.com/ankane/strong_migrations), running
`rails db:migrate` against a test DB is the deterministic check — it raises a descriptive error (with
the fix) on any unsafe operation, and is the natural CI gate. `safety_assured { ... }` is the escape
hatch for when you've made the operation safe by other means; always comment *why*. For the recommended
config, `safe_by_default`, and a review checklist, see `references/verification.md`.
