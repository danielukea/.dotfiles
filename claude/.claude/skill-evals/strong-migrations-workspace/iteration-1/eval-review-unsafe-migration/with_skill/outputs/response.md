# Migration Safety Review

**Verdict: Not safe to run as written — but only because of the index.** The `add_index` is unsafe; the `add_column` is fine on Postgres 14.

## The two operations

```ruby
class AddStatusToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :status, :string, default: "pending", null: false
    add_index :orders, :status
  end
end
```

### 1. `add_column :orders, :status, :string, default: "pending", null: false` — SAFE

This is the operation people most often assume is dangerous, but on your stack it is not.

- Postgres 11+ stores a **constant** non-null default as catalog metadata. It does **not** rewrite the table — adding the column is effectively instant regardless of how many rows `orders` has. (A full rewrite would only happen on Postgres < 11, or with a *volatile* default like `gen_random_uuid()` / `NOW()`. You're on PG 14 with the constant `"pending"`, so neither applies.)
- It is also safe for **rolling deploys**: old code running during the deploy window doesn't reference the new `status` column, and any rows old code inserts get the `"pending"` default — so the `NOT NULL` constraint is satisfied for both old and new writes.

No change needed to this line. Keep it exactly as written.

### 2. `add_index :orders, :status` — UNSAFE

This is the real problem. Without `algorithm: :concurrently`, Postgres acquires an **ACCESS EXCLUSIVE** lock on `orders` for the entire duration of the index build, **blocking all writes** (and the build scans every row — and every row now has a `status` value). On a populated production `orders` table during a rolling deploy, that's downtime.

## Why this must be split into two migrations

A concurrent index requires `disable_ddl_transaction!` (CONCURRENTLY cannot run inside a transaction). You don't want to disable the DDL transaction around the `add_column` as well, so the clean fix is to separate the two operations into two migrations.

## Recommended fix

**Migration 1 — add the column (unchanged, safe on PG 14):**

```ruby
class AddStatusToOrders < ActiveRecord::Migration[7.2]
  def change
    add_column :orders, :status, :string, default: "pending", null: false
  end
end
```

**Migration 2 — add the index concurrently:**

```ruby
class AddIndexOnOrdersStatus < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!  # required: CONCURRENTLY cannot run inside a transaction

  def change
    add_index :orders, :status, algorithm: :concurrently
  end
end
```

## Recommendation: install strong_migrations

If you don't already have it, add the [`strong_migrations`](https://github.com/ankane/strong_migrations) gem. It catches exactly this class of mistake at `rails db:migrate` time (and in CI), raising a descriptive error with the fix before the unsafe `add_index` ever reaches production. Setting `StrongMigrations.target_version = 14` makes its checks match your Postgres version — which is what tells it the `add_column` is safe and the bare `add_index` is not.

With `StrongMigrations.safe_by_default = true`, it will even auto-apply the concurrent-index pattern for you.
