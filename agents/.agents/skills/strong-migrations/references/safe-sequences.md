# Safe Sequences for Dangerous Operations

Each section is the full multi-step sequence for one operation. Read only the section you need —
the SKILL.md Quick Reference table names which one. Every sequence assumes a **rolling deploy**: the
schema must stay compatible with the code running *before* the deploy.

Examples use PostgreSQL and `ActiveRecord::Migration[8.0]`; adjust the version stamp to your app.

## Contents

- [Removing a Column](#removing-a-column)
- [Renaming a Column](#renaming-a-column)
- [Renaming a Table](#renaming-a-table)
- [Changing Column Type](#changing-column-type)
- [Adding a Column with a Non-Null Default](#adding-a-column-with-a-non-null-default)
- [Setting NOT NULL on an Existing Column](#setting-not-null-on-an-existing-column)
- [Adding an Index](#adding-an-index)
- [Adding a Foreign Key](#adding-a-foreign-key)
- [Adding a Check Constraint](#adding-a-check-constraint)
- [Backfilling Data](#backfilling-data)

---

## Removing a Column

ActiveRecord caches column lists at startup. If you drop a column that deployed code still references,
you get `ActiveRecord::UnknownAttributeError` — even code that never mentions the column crashes,
because AR wrote it into every INSERT/UPDATE.

**2-deploy sequence:**

**Deploy 1** — tell ActiveRecord to ignore the column, remove all code references:
```ruby
class User < ApplicationRecord
  self.ignored_columns += ["old_column"]
end
```

**Deploy 2** — drop the column:
```ruby
class RemoveOldColumnFromUsers < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :users, :old_column, :string }
  end
end
```

Give `remove_column` the original type/options so `down` can recreate it. Remove the `ignored_columns`
entry after the migration runs.

---

## Renaming a Column

Old code writes to `old_name`; new code reads from `new_name`. Without multi-step coordination, data
written during the deploy window is lost. Never use `rename_column` in one step on a live table.

**3-deploy sequence (expand/contract):**

**Deploy 1** — add the new column and write to both:
```ruby
class AddNewNameToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :new_name, :string
  end
end
```
Update the model/code to write to both columns (e.g. `before_save { self.new_name = old_name }`).

**Backfill** (separate migration after deploy 1 — see [Backfilling Data](#backfilling-data)):
```ruby
class BackfillNewName < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    User.unscoped.in_batches(of: 10_000) do |batch|
      batch.update_all("new_name = old_name")
      sleep(0.01)
    end
  end
end
```

**Deploy 2** — switch reads to `new_name`, stop writing `old_name`, ignore it:
```ruby
class User < ApplicationRecord
  self.ignored_columns += ["old_name"]
end
```

**Deploy 3** — drop the old column (see [Removing a Column](#removing-a-column)):
```ruby
class RemoveOldNameFromUsers < ActiveRecord::Migration[8.0]
  def change
    safety_assured { remove_column :users, :old_name, :string }
  end
end
```

---

## Renaming a Table

Same expand/contract approach as a column rename, at the table level:

1. Create the new table with the desired name.
2. Update writes to write to both tables.
3. Backfill the new table from the old (see [Backfilling Data](#backfilling-data)).
4. Switch reads to the new table.
5. Stop writing to the old table.
6. Drop the old table.

For simple, low-traffic cases, a database view over the old table name can bridge old code during the
transition. If no deployed code references the table at all, a single `safety_assured { rename_table }`
is safe — leave a comment explaining why.

---

## Changing Column Type

Most type changes cause a full table rewrite in Postgres, acquiring `ACCESS EXCLUSIVE` and blocking all
reads/writes. Use the same expand/contract pattern as [Renaming a Column](#renaming-a-column): add a
new column with the new type → dual-write → backfill with `in_batches` → switch reads →
`ignored_columns` old → drop old.

**Safe widening changes** (Postgres only, no table rewrite — can be done in place):
- `string` → increase/remove `:limit`, or → `text`
- `text` → `string` with no `:limit`; → `citext` if not indexed
- `decimal`/`numeric` → increase `:precision` at same `:scale`; or remove both
- `datetime` → increase/remove `:precision`; → `timestamptz` when session TZ is UTC
- `timestamptz` → increase/remove `:precision`; → `datetime` when session TZ is UTC
- `time`/`interval` → increase/remove `:precision`
- `cidr` → `inet`

Anything not on this list needs the full expand/contract sequence. `strong_migrations` will tell you
which case you are in — run `rails db:migrate` against a test DB and it either passes or prints the safe
rewrite.

---

## Adding a Column with a Non-Null Default

Postgres < 11 rewrites the entire table. Postgres 11+ handles it as a metadata-only change (instant) —
**but only for non-volatile defaults** (constants, not `NOW()` or `gen_random_uuid()`). With
`safe_by_default = true`, `strong_migrations` separates the operations for you.

**Manual safe approach (all versions):**
```ruby
# Step 1: add nullable column + default for new rows only
class AddStatusToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :status, :string
    change_column_default :users, :status, "active"
  end
end

# Step 2: backfill existing rows (separate migration, separate deploy)
class BackfillUsersStatus < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    User.unscoped.in_batches(of: 10_000) do |batch|
      batch.where(status: nil).update_all(status: "active")
      sleep(0.01)
    end
  end
end

# Step 3: add NOT NULL after backfill completes — see "Setting NOT NULL" below
```

**Volatile defaults** (`gen_random_uuid()`, `NOW()`):
```ruby
class AddUuidToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :uuid, :uuid
    change_column_default :users, :uuid, -> { "gen_random_uuid()" }
    # backfill existing rows separately
  end
end
```

---

## Setting NOT NULL on an Existing Column

`change_column_null :users, :col, false` validates the constraint in one transaction, taking a lock
that blocks all reads/writes for large tables. Add the constraint unvalidated first, then validate.

```ruby
# Migration 1: add as NOT VALID (no table scan, no blocking lock)
class AddNotNullConstraintOnUsersStatus < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :users, "status IS NOT NULL",
      name: "users_status_not_null", validate: false
  end
end

# After backfill completes — Migration 2: validate, then convert
class ValidateNotNullOnUsersStatus < ActiveRecord::Migration[8.0]
  def up
    # validate_check_constraint takes ShareUpdateExclusiveLock (allows reads/writes)
    validate_check_constraint :users, name: "users_status_not_null"
    change_column_null :users, :status, false  # safe now — already validated
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

## Adding an Index

Without `CONCURRENTLY`, Postgres holds `ACCESS EXCLUSIVE` on the table for the full index build,
blocking all writes. Always build concurrently, which requires disabling the migration's wrapping
transaction:

```ruby
class AddIndexOnUsersEmail < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!  # required — CONCURRENTLY cannot run inside a transaction

  def change
    add_index :users, :email, algorithm: :concurrently
  end
end
```

**Unique index:**
```ruby
class AddUniqueIndexOnUsersEmail < ActiveRecord::Migration[8.0]
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

**Adding an indexed reference/FK column.** Do NOT reach for `add_reference` in one step — it builds a
non-concurrent index (blocking) and adds a validated FK (blocking), and some projects ban it outright.
Split it into safe steps, each its own migration:
```ruby
# 1. add the plain column (fast, metadata-only)
add_column :products, :user_id, :bigint

# 2. index it concurrently (see above)
add_index :products, :user_id, algorithm: :concurrently   # in a disable_ddl_transaction! migration

# 3. add + validate the FK (see "Adding a Foreign Key")
```

**Removing an index** also needs `algorithm: :concurrently` + `disable_ddl_transaction!`:
```ruby
class RemoveSomeIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :users, column: :email, algorithm: :concurrently
  end

  def down
    add_index :users, :email, algorithm: :concurrently
  end
end
```

**Swapping an index:** add the replacement *before* removing the old one (add in one migration, remove
in the next) — never leave a hot column unindexed, even briefly.

---

## Adding a Foreign Key

Postgres validates all existing rows when adding a foreign key, taking `ACCESS EXCLUSIVE` on both
tables. Add unvalidated first, validate in a separate migration.

```ruby
# Migration 1: add without validation (no row scan)
class AddForeignKeyOnProductsUsers < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key :products, :users, validate: false
  end
end

# Migration 2: validate (ShareUpdateExclusiveLock — allows reads/writes)
class ValidateForeignKeyOnProductsUsers < ActiveRecord::Migration[8.0]
  def change
    validate_foreign_key :products, :users
  end
end
```

With `safe_by_default = true`, `strong_migrations` adds `validate: false` for you.

---

## Adding a Check Constraint

Same pattern — add unvalidated, validate separately.

```ruby
# Migration 1
class AddPriceCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :products, "price > 0",
      name: "products_price_positive", validate: false
  end
end

# Migration 2
class ValidatePriceCheckConstraint < ActiveRecord::Migration[8.0]
  def change
    validate_check_constraint :products, name: "products_price_positive"
  end
end
```

---

## Backfilling Data

Migrations run inside a transaction by default. A large `UPDATE` over thousands/millions of rows holds
a lock for its entire duration, blocking other queries.

**Keep backfills in their own migration, separate from schema changes.** Schema migrations should be
fast DDL; backfills are slow data operations with a different lifecycle and no meaningful rollback.

```ruby
class BackfillUsersRole < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!  # no wrapping transaction

  def up
    User.unscoped.in_batches(of: 10_000) do |batch|
      batch.where(role: nil).update_all(role: "member")
      sleep(0.01)  # yield between batches to avoid overwhelming the DB
    end
  end
end
```

- `unscoped` prevents default scopes from filtering out rows that need backfilling.
- `in_batches` + `update_all` issues one bulk UPDATE per batch (far fewer queries than `find_each`;
  intentionally skips validations/callbacks).
- Batch size 1,000–10,000 depending on row size and query complexity.
- `sleep(0.01)` is a courtesy throttle — increase for high-traffic tables or replica lag.

**A `disable_ddl_transaction!` migration must contain exactly one statement.** With no wrapping
transaction, if a second statement fails, the first is already committed and unrecoverable — the schema
is half-applied but Rails marks the migration pending. One operation per migration.

**For very large backfills**, use [Shopify's maintenance_tasks gem](https://github.com/Shopify/maintenance_tasks)
— purpose-built for data migrations outside schema migrations, with batching, throttling, and a web UI
to pause/resume.

The `up_only` helper runs a block only on `migrate:up`, never on rollback — handy for tiny inline
backfills where an inverse is meaningless:
```ruby
def change
  add_column :users, :role, :string
  up_only { User.update_all(role: "member") }  # only for small tables
end
```
