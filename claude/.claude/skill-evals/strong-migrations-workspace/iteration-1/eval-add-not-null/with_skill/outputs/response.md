# Adding a NOT NULL Constraint to `events.account_id` Without Downtime

## Why the naive approach is unsafe

The obvious migration is:

```ruby
change_column_null :events, :account_id, false
```

This is **not** safe for a large production table. `change_column_null` validates the constraint in a single transaction, and to do that Postgres must scan every row in `events`. While it scans, it holds an `ACCESS EXCLUSIVE` lock that blocks **all reads and writes** to the table for the entire duration. On a big `events` table that can be many seconds to minutes of downtime.

The fact that you've already backfilled the nulls is necessary but not sufficient — the data being valid doesn't change the fact that validating it inline takes a blocking lock.

## The safe approach: validated CHECK constraint, then convert

The trick is to split the work into two phases across two separate migrations:

1. Add a CHECK constraint as `NOT VALID` — this records the constraint and enforces it on all **new** writes, but does **not** scan existing rows, so it takes only a brief lock.
2. Validate the constraint in a separate migration — `validate_check_constraint` scans the table under a `SHARE UPDATE EXCLUSIVE` lock, which **allows concurrent reads and writes**. Once the constraint is proven valid, converting the column to `NOT NULL` is cheap because Postgres can use the already-validated CHECK constraint instead of re-scanning.

### Migration 1 — add the constraint as `NOT VALID` (no table scan, no blocking lock)

```ruby
class AddNotNullConstraintOnEventsAccountId < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :events, "account_id IS NOT NULL",
      name: "events_account_id_not_null", validate: false
  end
end
```

### Migration 2 — validate and convert (run after Migration 1 has deployed)

```ruby
class ValidateNotNullOnEventsAccountId < ActiveRecord::Migration[7.2]
  def up
    # validate_check_constraint takes a SHARE UPDATE EXCLUSIVE lock — reads/writes continue
    validate_check_constraint :events, name: "events_account_id_not_null"

    # Now safe: the validated CHECK lets Postgres set NOT NULL without a full re-scan
    change_column_null :events, :account_id, false

    # Optional: drop the redundant CHECK now that the column itself is NOT NULL
    remove_check_constraint :events, name: "events_account_id_not_null"
  end

  def down
    add_check_constraint :events, "account_id IS NOT NULL",
      name: "events_account_id_not_null", validate: false
    change_column_null :events, :account_id, true
  end
end
```

## Notes

- **Keep the two migrations separate.** Migration 1 acquires only a brief lock; Migration 2 does the scan-heavy validation under a non-blocking lock. Putting both in one migration would re-introduce the long lock you're trying to avoid.
- **Backfill must be fully complete before Migration 1 deploys.** If any null `account_id` rows remain when the `NOT VALID` constraint is added, new writes that violate it are rejected, and the later `validate_check_constraint` will fail. Since you've already backfilled, you're good — just confirm no nulls have crept back in (`SELECT 1 FROM events WHERE account_id IS NULL LIMIT 1`).
- **The `remove_check_constraint` step is optional.** Once the column is `NOT NULL`, the CHECK constraint is redundant; removing it keeps the schema clean. You can also leave it — it does no harm.
- **Postgres 12+ optimization:** From Postgres 12 onward, `change_column_null` will recognize a pre-existing validated `NOT NULL`-equivalent CHECK constraint and skip the full table re-scan, which is exactly why this two-step sequence works. (`StrongMigrations.target_version` should be set to your production Postgres major version so the gem's checks match production behavior.)

## Verifying safety with strong_migrations

If the `strong_migrations` gem is installed, it acts as your deterministic CI gate. Running `rails db:migrate` against a test database will raise a descriptive error on the naive `change_column_null` migration and point you toward this exact check-constraint sequence. Run it in CI to fail the build before any unsafe migration reaches production.
