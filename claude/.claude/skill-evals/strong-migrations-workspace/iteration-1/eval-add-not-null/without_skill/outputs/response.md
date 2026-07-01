# Adding a NOT NULL constraint without downtime

Good news: you've already done the hard part by backfilling the nulls. The challenge now is purely about *how* you add the constraint, because the naive approach causes downtime even when there are no nulls to worry about.

## Why the naive approach is dangerous

```ruby
class AddNotNullToEventsAccountId < ActiveRecord::Migration[7.1]
  def change
    change_column_null :events, :account_id, false
  end
end
```

On Postgres, `change_column_null ..., false` (which runs `ALTER TABLE ... ALTER COLUMN ... SET NOT NULL`) requires a **full table scan** while holding an `ACCESS EXCLUSIVE` lock. Postgres has to verify that *every existing row* satisfies the constraint, and during that scan no other query can read or write the table. On a large `events` table this can lock the table for seconds to minutes — that's your downtime.

(Note: Postgres 12+ can skip the validating scan if there's already a validated `CHECK (account_id IS NOT NULL)` constraint on the table — that's exactly the trick we exploit below.)

## The safe, zero-downtime sequence (Postgres)

The pattern is **add a CHECK constraint NOT VALID → validate it separately → promote to a real NOT NULL → drop the CHECK**. The key insight is that adding a constraint as `NOT VALID` only takes a brief lock and does *not* scan the table, and validating it later takes only a `SHARE UPDATE EXCLUSIVE` lock that does not block reads or writes.

### Migration 1 — add the CHECK constraint as NOT VALID

```ruby
class AddEventsAccountIdNullCheck < ActiveRecord::Migration[7.1]
  def change
    # Brief ACCESS EXCLUSIVE lock, but NO table scan — fast even on huge tables.
    # All NEW rows are enforced immediately; existing rows are not yet checked.
    add_check_constraint :events, "account_id IS NOT NULL",
                         name: "events_account_id_null", validate: false
  end
end
```

Deploy this. From this point forward, any insert/update with a null `account_id` is rejected, so no new nulls can sneak in.

### Migration 2 — validate the constraint (separate migration / deploy)

```ruby
class ValidateEventsAccountIdNullCheck < ActiveRecord::Migration[7.1]
  def change
    # Scans the table to verify existing rows, but only takes a
    # SHARE UPDATE EXCLUSIVE lock — reads and writes continue normally.
    validate_check_constraint :events, name: "events_account_id_null"
  end
end
```

Because you've already backfilled, this validation will succeed. It does scan the table, but it does **not** block concurrent reads/writes — that's the whole point.

### Migration 3 (optional but recommended) — promote to a real NOT NULL and drop the CHECK

A validated `CHECK (col IS NOT NULL)` constraint is functionally equivalent to a column `NOT NULL`, so many teams stop after migration 2. But if you want the constraint to show up as a true column-level `NOT NULL` in the schema (cleaner, and what most tooling expects), you can now promote it cheaply:

```ruby
class SetEventsAccountIdNotNull < ActiveRecord::Migration[7.1]
  def up
    # On Postgres 12+, SET NOT NULL detects the already-validated CHECK
    # constraint and SKIPS the full table scan — so this is fast.
    change_column_null :events, :account_id, false
    remove_check_constraint :events, name: "events_account_id_null"
  end

  def down
    add_check_constraint :events, "account_id IS NOT NULL",
                         name: "events_account_id_null", validate: false
    change_column_null :events, :account_id, true
  end
end
```

On Postgres 12+, `SET NOT NULL` will recognize the existing validated CHECK constraint and skip the expensive scan, so this migration is fast. After it commits you can drop the now-redundant CHECK constraint.

## A note on deploy ordering

Run each migration in its own deploy. In particular, **do not** combine "add NOT VALID" and "validate" in a single transaction — if they share a transaction, the validation runs while the table is still effectively locked from the add, defeating the purpose. Separating them (ideally across deploys) keeps locks short.

## What about MySQL?

The `NOT VALID` / `VALIDATE` dance is Postgres-specific. On MySQL, `change_column_null` does not take the same kind of blocking lock for this operation in modern versions, but if you're on MySQL the safe path is typically to use an online schema change tool (gh-ost or pt-online-schema-change) for large tables. The answer above assumes Postgres, which is the common case for Rails apps.

## TL;DR

1. **Backfill nulls** — done.
2. **Migration 1:** `add_check_constraint :events, "account_id IS NOT NULL", validate: false` (fast, blocks new nulls).
3. **Migration 2 (separate deploy):** `validate_check_constraint` (scans without blocking reads/writes).
4. **Migration 3 (optional):** `change_column_null ..., false` (now scan-free on PG 12+) and drop the CHECK constraint.

Each step takes only short-lived locks, so the table stays available throughout — no downtime.
