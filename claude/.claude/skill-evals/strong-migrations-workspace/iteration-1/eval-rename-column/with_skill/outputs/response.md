# Renaming `email` → `email_address` Safely (2M rows, rolling deploys)

## Why you can't just `rename_column`

With rolling deploys, old and new app code run **simultaneously** during the deploy window. A single-step `rename_column :users, :email, :email_address` breaks this in two ways:

1. **Data loss.** Old code (still running) keeps writing to `email`. After the rename, that column no longer exists — those writes error out, or worse, if you've also shipped code expecting `email_address`, writes split across two names and get lost.
2. **Crashes.** ActiveRecord caches the column list at boot. Old instances expect `email`; the moment the column is renamed out from under them, they raise `UnknownAttributeError` until they're replaced.

**The rule:** every migration must leave the schema compatible with the code that was running *before* the deploy. A rename violates that, so we split it into an **expand/contract** sequence across **3 deploys**.

---

## The 3-Deploy Sequence

### Deploy 1 — Expand: add the new column and dual-write

Add `email_address` as a new nullable column. It must be nullable here — old rows haven't been backfilled yet, and old code doesn't know about it.

```ruby
class AddEmailAddressToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :email_address, :string
  end
end
```

Then update the model to **write to both columns** so no data is lost during the transition. Reads still come from the old `email`:

```ruby
class User < ApplicationRecord
  before_save do
    self.email_address = email if will_save_change_to_email?
  end
end
```

After this deploy: old code writes `email` (fine, still the source of truth); new code writes both. The new column exists but is empty for historical rows.

### Backfill — copy existing 2M rows in batches (separate migration, after Deploy 1)

Do **not** do this as a single `UPDATE` — on 2M rows it holds a lock for the entire statement and blocks other queries. Batch it, outside a transaction:

```ruby
class BackfillEmailAddress < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    User.unscoped.in_batches(of: 10_000) do |batch|
      batch.where(email_address: nil).update_all("email_address = email")
      sleep(0.01)  # throttle so you don't overwhelm the DB
    end
  end

  def down
    # no-op
  end
end
```

- `disable_ddl_transaction!` keeps each batch in its own short transaction instead of one giant lock.
- `unscoped` ensures no default scope hides rows that still need backfilling.
- `where(email_address: nil)` makes it idempotent and re-runnable.
- At 2M rows / 10k batches that's ~200 batches — fast and non-blocking.

### Restore NOT NULL — if `email` was `NOT NULL` (after backfill, before Deploy 3)

A faithful rename should preserve the original column's constraints. The `email` column on a users table is almost certainly `NOT NULL`, but `email_address` was added nullable for the transition — so you need to restore the constraint, or the "rename" silently weakens your schema. Skip this section only if `email` was actually nullable.

Don't use `change_column_null :users, :email_address, false` directly — it validates the constraint in one transaction, taking a lock that blocks all reads/writes while it scans 2M rows. Use the check-constraint approach: add it `NOT VALID` (instant, no scan), validate separately (a lighter `ShareUpdateExclusiveLock` that allows reads/writes), then convert.

```ruby
# Migration A: add the constraint without validating (no table scan, no blocking lock)
class AddEmailAddressNotNullConstraint < ActiveRecord::Migration[7.2]
  def change
    add_check_constraint :users, "email_address IS NOT NULL",
      name: "users_email_address_not_null", validate: false
  end
end

# Migration B (after backfill is fully complete): validate and convert to a real NOT NULL
class ValidateEmailAddressNotNull < ActiveRecord::Migration[7.2]
  def up
    validate_check_constraint :users, name: "users_email_address_not_null"
    change_column_null :users, :email_address, false  # safe — already validated
    remove_check_constraint :users, name: "users_email_address_not_null"
  end

  def down
    add_check_constraint :users, "email_address IS NOT NULL",
      name: "users_email_address_not_null", validate: false
    change_column_null :users, :email_address, true
  end
end
```

Run Migration A after the backfill; run Migration B once you're confident every row (including any written mid-deploy) satisfies the constraint.

### Deploy 2 — Switch: read from the new column, stop writing the old

Now that every row has `email_address` populated and both columns stay in sync, flip reads to the new column, stop the dual-write, and tell ActiveRecord to ignore `email` so the next deploy can safely drop it:

```ruby
class User < ApplicationRecord
  self.ignored_columns += ["email"]
  # remove the dual-write before_save callback
  # update all references from `email` to `email_address`
end
```

`ignored_columns` makes AR behave as if `email` doesn't exist, so once this deploy is fully rolled out, dropping the column won't crash any running instance.

### Deploy 3 — Contract: drop the old column

Only after Deploy 2 is fully rolled out (no instance still references `email`):

```ruby
class RemoveEmailFromUsers < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :users, :email }
  end
end
```

Then remove the `self.ignored_columns += ["email"]` line — its job is done.

---

## Don't forget the index / uniqueness constraint

`email` almost certainly has a unique index. You need an equivalent on `email_address`. Add it **concurrently** so it doesn't lock the table (an index built without `CONCURRENTLY` takes `ACCESS EXCLUSIVE` and blocks all writes for the full build — unacceptable on 2M rows):

```ruby
class AddIndexOnUsersEmailAddress < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!  # CONCURRENTLY can't run inside a transaction

  def change
    add_index :users, :email_address, unique: true, algorithm: :concurrently
  end
end
```

Add this around Deploy 1 (after the backfill, so existing duplicates surface and the index can build against real data). For a unique constraint specifically:

```ruby
add_index :users, :email_address, unique: true, algorithm: :concurrently
add_unique_constraint :users, using_index: "index_users_on_email_address"
```

---

## Catch this automatically

Install [`strong_migrations`](https://github.com/ankane/strong_migrations). It raises a descriptive error at `rails db:migrate` time on any unsafe operation — a bare `rename_column` or a non-concurrent index — and tells you exactly how to fix it. Wire `rails db:migrate` into CI against a test DB and it becomes a build gate: unsafe migrations fail before they ever reach production.

```ruby
# Gemfile
gem "strong_migrations"
```

```ruby
# config/initializers/strong_migrations.rb
StrongMigrations.safe_by_default = true   # auto-applies concurrent indexes, etc.
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.target_version = 16      # match your production Postgres major version
```

Note on `safety_assured`: it's the escape hatch used in Deploy 3 — legitimate there *because* you've completed the multi-step sequence and `email` is already in `ignored_columns` across all deployed code. Don't reach for it to silence the warning on a one-step rename; that's exactly the unsafe case the gem is protecting you from.

---

## Summary

| Step | Action | Why it's safe |
|------|--------|---------------|
| Deploy 1 | Add nullable `email_address`, dual-write | Old code still uses `email`; no schema break |
| Backfill | Batched `update_all`, `disable_ddl_transaction!` | No long lock on 2M rows |
| (index) | `add_index ... algorithm: :concurrently` | No `ACCESS EXCLUSIVE` lock |
| (NOT NULL) | Check constraint `validate: false` → validate → `change_column_null` | Restores constraint without a blocking scan (if `email` was NOT NULL) |
| Deploy 2 | Read `email_address`, stop dual-write, `ignored_columns += ["email"]` | New column fully populated and in sync |
| Deploy 3 | `remove_column :users, :email` | No running code references `email` |

Three deploys is the cost of a zero-downtime rename. Skipping any step reintroduces either data loss (writes to the dropped/renamed column) or crashes (AR's cached column list). Wait for each deploy to fully roll out before starting the next.
