---
name: strong-migrations
description: Use when writing, reviewing, planning, or verifying Rails database migrations — especially any migration that removes, renames, changes the type of, adds constraints to, or adds indexes on existing production columns or tables. Always invoke for questions about zero-downtime deployments, rolling deploys, and schema changes that could cause errors while old code is still running. Covers deterministic safety verification via the strong_migrations gem, the full expand/contract multi-deploy pattern, and every dangerous operation with its safe multi-step sequence. Trigger even if the user just asks "is this migration safe?" or pastes migration code for review.
---

# Safe Zero-Downtime Rails Migrations

## Why This Matters

Two independent failure modes can cause downtime during a migration:

**1. App/schema mismatch.** Rolling deploys run old and new code simultaneously. Old code expects the old schema; new code expects the new one. Worse: ActiveRecord caches the full column list at boot and uses it to build every INSERT/UPDATE. Code that never explicitly references a dropped column will still crash because AR wrote that column to every row.

**2. Lock queue head-of-line blocking.** Many DDL operations take an `ACCESS EXCLUSIVE` lock, which conflicts with everything — including plain SELECTs. The dangerous part isn't just the lock itself: a pending DDL request that can't immediately acquire the lock sits in the queue, and *every* subsequent query on that table queues behind it. One slow query + one DDL = the entire table appears frozen until the slow query finishes.

**The rule:** Every migration must leave the schema compatible with the code running *before* the deploy.

This means:
- Don't drop a column until all code that references it is gone
- Don't rename a column in one step (old code writes to old name, causing data loss)
- Don't add a NOT NULL constraint until every existing row satisfies it
- Don't add an index without `CONCURRENTLY` — it locks the table for the full duration
- Set `lock_timeout` so DDL aborts fast instead of forming a kill queue

## Deterministic Safety Verification with strong_migrations

The [strong_migrations gem](https://github.com/ankane/strong_migrations) catches unsafe migrations *at runtime* — when you run `rails db:migrate`, it raises a descriptive error before the operation executes, with instructions for how to fix it.

```ruby
# Gemfile
gem "strong_migrations"

# Install (generates a configured initializer)
rails generate strong_migrations:install
```

**This is your CI gate.** Run `rails db:migrate` against a test database in CI, and strong_migrations will fail the build on any unsafe migration before it ever reaches production.

### Recommended configuration

```ruby
# config/initializers/strong_migrations.rb
StrongMigrations.start_after = 20250101000000  # skip historical migrations

# Auto-applies safe patterns for indexes, foreign keys, check constraints
StrongMigrations.safe_by_default = true

# Prevent runaway lock waits
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour

# Retry on lock timeout for busy tables
StrongMigrations.lock_timeout_retries = 3
StrongMigrations.lock_timeout_retry_delay = 10.seconds

# Match production Postgres version for accurate checks
StrongMigrations.target_version = 16  # Postgres major version

# Also validate rollback migrations (off by default — useful for CI)
StrongMigrations.check_down = true

# ANALYZE table after adding an index (keeps planner stats fresh)
StrongMigrations.auto_analyze = true
```

> **Note:** strong_migrations does NOT automatically detect dangerous backfills. It catches structural DDL operations, but a large unthrottled `UPDATE` inside a transaction is not blocked — you must apply the `disable_ddl_transaction!` + `in_batches` pattern manually.

### The safety_assured escape hatch

```ruby
# Only use after verifying the operation is safe for your specific situation
safety_assured { remove_column :users, :legacy_field }
```

Never use this as a shortcut. It exists for situations where you've completed the multi-step sequence and strong_migrations doesn't have context (e.g., "this column is already `ignored_columns` in all deployed code"). Always leave a comment explaining *why* the operation is safe:

```ruby
# safety_assured: no deployed code reads or writes this table — renaming is safe
safety_assured { rename_table :old_name, :new_name }
```

---

## Quick Reference

| Operation | Danger | Safe approach |
|-----------|--------|---------------|
| Remove column | AR caches columns; old code crashes | `ignored_columns` → deploy → then drop |
| Rename column | Old code writes to wrong name → data loss | Expand/contract: 3 deploys |
| Rename table | Old code references old name → errors | Expand/contract: 3 deploys |
| Change column type | Table rewrite, full lock | Add new col → backfill → switch → drop old |
| Add column with non-null default (PG < 11) | Table rewrite | Add nullable → backfill → add constraint |
| Add index (Postgres) | Blocks writes for full duration | `algorithm: :concurrently` + `disable_ddl_transaction!` |
| Add foreign key | ACCESS EXCLUSIVE on both tables | `validate: false` → validate separately |
| Add check constraint | Locks during row scan | `validate: false` → validate separately |
| Set NOT NULL | Locks during validation | Check constraint approach (below) |
| Backfill large table | Long transaction holds lock | `disable_ddl_transaction!` + `in_batches` |

---

## Dangerous Operations: Safe Sequences

### Removing a Column

ActiveRecord caches column lists at startup. If you drop a column that deployed code still references, you get `ActiveRecord::UnknownAttributeError`.

**2-deploy sequence:**

**Deploy 1** — tell ActiveRecord to ignore the column, remove all code references:
```ruby
class User < ApplicationRecord
  self.ignored_columns += ["old_column"]
end
```

**Deploy 2** — drop the column:
```ruby
class RemoveOldColumnFromUsers < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :users, :old_column }
  end
end
```

Remove the `ignored_columns` entry after the migration runs.

---

### Renaming a Column

Old code writes to `old_name`; new code reads from `new_name`. Without multi-step coordination, data written during the deploy window is lost.

**3-deploy sequence:**

**Deploy 1** — add the new column and write to both:
```ruby
class AddNewNameToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :new_name, :string
  end
end
```
Update model/code to write to both columns (e.g., `before_save { self.new_name = old_name }`).

**Backfill** (run as a separate migration after deploy 1):
```ruby
class BackfillNewName < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    User.unscoped.in_batches(of: 10_000) do |batch|
      batch.update_all("new_name = old_name")
      sleep(0.01)
    end
  end
end
```

**Deploy 2** — switch reads to `new_name`, stop writing to `old_name`, ignore it:
```ruby
class User < ApplicationRecord
  self.ignored_columns += ["old_name"]
end
```

**Deploy 3** — drop the old column:
```ruby
class RemoveOldNameFromUsers < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :users, :old_name }
  end
end
```

---

### Changing Column Type

Most type changes cause a full table rewrite in Postgres, acquiring ACCESS EXCLUSIVE and blocking all reads/writes. Uses the same expand/contract pattern as renaming.

**Steps:** add new column with new type → dual-write → backfill with `in_batches` → switch reads → `ignored_columns` old → drop old.

**Safe widening changes** (Postgres only, no table rewrite):
- `string` → increase/remove `:limit`, or `text`
- `text` → `string` with no `:limit`; → `citext` if not indexed
- `decimal`/`numeric` → increase `:precision` at same `:scale`; or remove both
- `datetime` → increase/remove `:precision`; → `timestamptz` when session TZ is UTC
- `timestamptz` → increase/remove `:precision`; → `datetime` when session TZ is UTC
- `time`/`interval` → increase/remove `:precision`
- `cidr` → `inet`

Anything not in this list requires the full expand/contract sequence. strong_migrations will tell you if your specific change is safe — run `rails db:migrate` against a test DB and it will either pass or print the safe rewrite.

---

### Adding a Column with Non-Null Default

Postgres < 11 rewrites the entire table. Postgres 11+ handles this as a metadata-only change (instant) — **but only for non-volatile defaults** (constants, not `NOW()` or `gen_random_uuid()`).

**With `safe_by_default = true`**, strong_migrations handles this automatically by separating the operations.

**Manual safe approach (all versions):**
```ruby
# Step 1: Add nullable column
class AddStatusToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :status, :string
    change_column_default :users, :status, "active"  # for new rows only
  end
end

# Step 2: Backfill (separate migration, separate deploy)
class BackfillUsersStatus < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    User.unscoped.in_batches(of: 10_000) do |batch|
      batch.where(status: nil).update_all(status: "active")
      sleep(0.01)
    end
  end
end

# Step 3: Add NOT NULL after backfill is complete (see "Setting NOT NULL" below)
```

**Volatile defaults** (functions like `gen_random_uuid()`, `NOW()`):
```ruby
class AddUuidToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :uuid, :uuid
    change_column_default :users, :uuid, -> { "gen_random_uuid()" }
    # Backfill separately
  end
end
```

---

### Setting NOT NULL on an Existing Column

`change_column_null :users, :col, false` validates the constraint in one transaction, acquiring a lock that blocks all reads/writes for large tables.

**Safe approach using check constraint:**

```ruby
# Migration 1: Add constraint as NOT VALID (no table scan, no lock)
class AddNotNullConstraintOnUsersStatus < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :users, "status IS NOT NULL",
      name: "users_status_not_null", validate: false
  end
end

# After backfill is complete — Migration 2: Validate and convert
class ValidateNotNullOnUsersStatus < ActiveRecord::Migration[7.2]
  def up
    # validate_check_constraint takes ShareUpdateExclusiveLock (allows reads/writes)
    validate_check_constraint :users, name: "users_status_not_null"
    change_column_null :users, :status, false  # now safe — constraint already validated
    remove_check_constraint :users, name: "users_status_not_null"
  end

  def down
    add_check_constraint :users, "status IS NOT NULL",
      name: "users_status_not_null", validate: false
    change_column_null :users, :status, true
  end
end
```

---

### Adding an Index (PostgreSQL)

Without `CONCURRENTLY`, Postgres acquires ACCESS EXCLUSIVE on the table for the full index build — blocking all writes.

```ruby
class AddIndexOnUsersEmail < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!  # required — CONCURRENTLY cannot run inside a transaction

  def change
    add_index :users, :email, algorithm: :concurrently
  end
end
```

For **unique indexes**:
```ruby
class AddUniqueIndexOnUsersEmail < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_index :users, :email, unique: true, algorithm: :concurrently
    add_unique_constraint :users, using_index: "index_users_on_email"
  end

  def down
    remove_unique_constraint :users, :email
  end
end
```

For **`add_reference`**:
```ruby
class AddCityToUsers < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_reference :users, :city, index: {algorithm: :concurrently}
  end
end
```

**Removing an index** also requires `algorithm: :concurrently` + `disable_ddl_transaction!`:
```ruby
class RemoveSomeIndex < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def up
    remove_index :table_name, column: :col, algorithm: :concurrently
  end

  def down
    add_index :table_name, :col, algorithm: :concurrently
  end
end
```

When swapping an index, **add the replacement before removing the old one** — never leave a critical column unindexed, even briefly (add in one migration, remove in the next).

---

### Adding a Foreign Key

Postgres validates all existing rows when adding a foreign key, acquiring ACCESS EXCLUSIVE on both tables.

**2-migration sequence:**
```ruby
# Migration 1: Add without validation (no row scan)
class AddForeignKeyOnUsersOrders < ActiveRecord::Migration[7.2]
  def change
    add_foreign_key :users, :orders, validate: false
  end
end

# Migration 2: Validate (ShareUpdateExclusiveLock — allows reads/writes)
class ValidateForeignKeyOnUsersOrders < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :users, :orders
  end
end
```

With `safe_by_default = true`, strong_migrations adds `validate: false` automatically.

---

### Adding a Check Constraint

Same pattern — add unvalidated first, validate in a separate migration.

```ruby
# Migration 1
class AddPriceCheckConstraint < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :products, "price > 0",
      name: "products_price_positive", validate: false
  end
end

# Migration 2
class ValidatePriceCheckConstraint < ActiveRecord::Migration[7.2]
  def change
    validate_check_constraint :products, name: "products_price_positive"
  end
end
```

---

### Backfilling Data

Migrations run inside a transaction by default. A large `UPDATE` on thousands/millions of rows holds a lock for its entire duration, blocking other queries.

**Keep backfill migrations separate from schema change migrations.** Schema migrations should be fast DDL; backfills are slow data operations with a different lifecycle and no meaningful rollback.

```ruby
class BackfillUsersRole < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!  # no wrapping transaction

  def up
    User.unscoped.in_batches(of: 10_000) do |batch|
      batch.where(role: nil).update_all(role: "member")
      sleep(0.01)  # yield between batches to avoid overwhelming the DB
    end
  end
end
```

- `unscoped` prevents default scopes from filtering rows that need backfilling
- `in_batches` + `update_all` issues one bulk UPDATE per batch (far fewer queries than `find_each`; skips validations/callbacks intentionally)
- Batch size: 1,000–10,000 rows depending on row size and query complexity
- `sleep(0.01)` is a courtesy throttle — increase for high-traffic tables or replica lag

**Critical: `disable_ddl_transaction!` migrations must contain exactly one statement.** Without a wrapping transaction, if a second statement fails, the first is already committed and unrecoverable — the schema is half-applied but Rails marks the migration pending. One operation per migration.

**For very large backfills**, consider [Shopify's maintenance_tasks gem](https://github.com/Shopify/maintenance_tasks) — purpose-built for data migrations outside schema migrations, with batching, built-in throttling, a web UI to pause/resume, and GoodJob/Sidekiq backing.

The `up_only` helper runs a block only on `migrate:up`, never on rollback — useful for small inline backfills where an inverse is meaningless:
```ruby
def change
  add_column :users, :role, :string
  up_only { User.update_all(role: "member") }  # only for small tables
end
```

---

## Renaming a Table

Use the same expand/contract approach as renaming a column, but at the table level:

1. Create the new table with the desired name
2. Update writes to write to both tables
3. Backfill the new table from the old
4. Switch reads to the new table
5. Stop writing to the old table
6. Drop the old table

For simple cases on low-traffic tables, a DB view over the old table name can bridge old code during the transition.

---

## Reviewing a Migration for Safety

When asked to review a migration, check:

1. Does it remove or rename a column/table? → needs ignored_columns + multi-deploy
2. Does it add an index without `algorithm: :concurrently`? → needs CONCURRENTLY + `disable_ddl_transaction!`
3. Does it add a foreign key without `validate: false`? → needs 2-migration split
4. Does it add a check constraint without `validate: false`? → same
5. Does it set NOT NULL via `change_column_null`? → needs check constraint approach
6. Does it backfill inside a transaction? → needs `disable_ddl_transaction!` + `in_batches`
7. Does it change a column type? → check if it's a safe widening; otherwise expand/contract
8. Does it add a column with a volatile default (function call)? → add then set default separately
9. Does it use `disable_ddl_transaction!` with more than one statement? → split into separate migrations

**The fastest check**: if the project has `strong_migrations` installed, run `rails db:migrate` against a test DB — it will raise a descriptive error for any unsafe operation and tell you exactly what to do.
