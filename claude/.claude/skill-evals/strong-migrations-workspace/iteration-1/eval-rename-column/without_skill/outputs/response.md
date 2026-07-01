# Safely Renaming `email` → `email_address` (2M rows, rolling deploys)

Short answer: **do not rename the column directly.** A direct rename is unsafe under rolling deploys and you should avoid it. Instead use the **expand / migrate / contract** pattern across multiple deploys so that old and new code can run simultaneously without errors.

## Why a direct rename is dangerous

A single `rename_column :users, :email, :email_address` looks harmless, but during a rolling deploy you have **two versions of your application running at the same time**:

- **Old code** still references `email` (in SQL, ActiveRecord attribute methods, cached column lists, etc.).
- **New code** references `email_address`.

The instant the migration runs, the `email` column no longer exists. Every old process that still queries `email` immediately starts throwing errors (`PG::UndefinedColumn` / `column "email" does not exist`) until every old process is recycled. With 2M rows and rolling deploys, that window is real and will produce a burst of 500s.

There's a second, sneakier problem specific to Rails: ActiveRecord **caches the schema/column list** at boot. Even if you used the trick of pointing Rails at the new name, old running processes have the old column cached. Renames break this caching contract.

The rename itself is metadata-only in Postgres (fast, takes `ACCESS EXCLUSIVE` very briefly), so the danger is **not** lock duration — it's the **application-level incompatibility** between the two running code versions.

## The safe path: expand / migrate / contract

The core idea: never have a moment where running code references a column that doesn't exist. You add the new column, keep both in sync, migrate reads/writes over, and only remove the old column once nothing references it.

### Deploy 1 — Add the new column (expand)

```ruby
class AddEmailAddressToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :email_address, :string
  end
end
```

`add_column` with no default and no `NOT NULL` is safe — it's a fast metadata change in modern Postgres and doesn't rewrite the table.

### Deploy 2 — Write to both columns

Update the application so that every write to `email` also writes to `email_address`. The cleanest way is to keep `email` as the "source of truth" for now and mirror it:

```ruby
class User < ApplicationRecord
  before_save :sync_email_address

  private

  def sync_email_address
    self.email_address = email if email_changed?
  end
end
```

Now any new or updated record keeps both columns consistent. Old code that only knows about `email` still works (it's still the canonical column). New code can start reading `email_address` for freshly-written rows.

### Backfill the existing 2M rows (in batches)

Existing rows still have `email_address = NULL`. Backfill in batches to avoid a single huge transaction, long locks, and replication lag:

```ruby
class BackfillEmailAddress < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!  # don't wrap the whole backfill in one transaction

  def up
    User.unscoped.in_batches(of: 10_000) do |relation|
      relation.where(email_address: nil).update_all("email_address = email")
      sleep(0.1)  # throttle to ease DB / replica load
    end
  end

  def down
    # no-op
  end
end
```

Key points:
- `disable_ddl_transaction!` so each batch commits independently instead of holding one giant transaction open.
- `in_batches` (or `find_in_batches`) keeps each `UPDATE` bounded — important at 2M rows.
- A small `sleep` throttles load and gives replicas room to keep up.
- `update_all` with raw SQL avoids instantiating 2M AR objects and skips callbacks.

### Deploy 3 — Read from the new column

Now that both columns are fully in sync and backfilled, switch all **reads** in the application to `email_address`. Continue writing to both (keep the sync from Deploy 2) so that if you need to roll back this deploy, `email` is still correct.

At this point `email_address` is the column the app actually reads.

### Deploy 4 — Stop using `email` entirely

Remove the dual-write sync code and any remaining references to `email`. After this deploy ships and all old processes are gone, **nothing in the running application references `email` anymore.**

### Deploy 5 — Drop the old column (contract)

Only now is it safe to remove `email`:

```ruby
class RemoveEmailFromUsers < ActiveRecord::Migration[7.1]
  def up
    safety_assured { remove_column :users, :email }
  end

  def down
    add_column :users, :email, :string
  end
end
```

Two Rails-specific notes when dropping a column:
- Add the column to `self.ignored_columns` **before** dropping it (in an earlier deploy), so ActiveRecord's cached schema doesn't try to select a column that's about to disappear. Otherwise you can hit the same "two versions running" error in reverse.
- Removing a column should be its own final deploy.

## Things to watch out for along the way

- **Indexes / unique constraints:** `email` almost certainly has a unique index. You'll want the same on `email_address`. Create it `algorithm: :concurrently` (with `disable_ddl_transaction!`) so you don't take a long exclusive lock on a 2M-row table:
  ```ruby
  add_index :users, :email_address, unique: true, algorithm: :concurrently
  ```
  But note: a unique index can't be created until the backfill is done and the column has no duplicate/NULL conflicts — sequence it after the backfill.
- **NOT NULL:** if `email` was `NOT NULL`, don't slap `NOT NULL` on `email_address` at creation (that would require a default or a rewrite). Add it later via a validated check constraint or after backfill.
- **Validations / uniqueness validators:** keep model validations pointing at whatever the canonical column is at each stage so you don't get spurious validation failures during the transition.
- **Foreign code:** search for `email` everywhere — serializers, API responses, background jobs, reports, search indexing, third-party integrations, raw SQL, views. All of them need to move to `email_address` before Deploy 5.
- **Replica lag:** the batched backfill with throttling is specifically to protect read replicas; monitor lag while it runs.

## Consider: do you even need to rename it?

Renaming a heavily-referenced column is a lot of multi-deploy ceremony for a cosmetic change. If the real goal is just a nicer name in code, an alias (`alias_attribute :email_address, :email`) gives you the new name in Ruby with **zero** schema risk. Only do the full physical rename if you genuinely need the database column itself renamed (e.g., shared DB consumers, naming standards enforced at the DB layer).

## TL;DR sequence

1. **Deploy 1:** `add_column :email_address` (nullable, no default).
2. **Deploy 2:** dual-write — keep `email_address` in sync with `email`.
3. **Backfill** existing rows in throttled batches; add concurrent unique index after.
4. **Deploy 3:** switch reads to `email_address` (still dual-writing).
5. **Deploy 4:** remove all `email` references; add `email` to `ignored_columns`.
6. **Deploy 5:** `remove_column :email`.

Each deploy is independently safe because at no point does running code (old or new) reference a column that doesn't exist.
