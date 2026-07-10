# Verifying Migration Safety with strong_migrations

The [strong_migrations gem](https://github.com/ankane/strong_migrations) catches unsafe migrations *at
runtime* — when you run `rails db:migrate`, it raises a descriptive error before the operation executes,
with instructions for the safe rewrite.

```ruby
# Gemfile
gem "strong_migrations"

# Install (generates a configured initializer)
rails generate strong_migrations:install
```

**This is your CI gate.** Run `rails db:migrate` against a test database in CI, and strong_migrations
fails the build on any unsafe migration before it reaches production. It is far more reliable than
eyeballing the migration.

## Recommended configuration

```ruby
# config/initializers/strong_migrations.rb
StrongMigrations.start_after = 20250101000000  # skip pre-existing historical migrations

# Auto-apply safe patterns for indexes, foreign keys, check constraints
StrongMigrations.safe_by_default = true

# Prevent runaway lock waits — DDL aborts fast instead of forming a kill queue
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour

# Retry on lock timeout for busy tables
StrongMigrations.lock_timeout_retries = 3
StrongMigrations.lock_timeout_retry_delay = 10.seconds

# Match production Postgres version for accurate checks
StrongMigrations.target_version = 16

# Also validate rollback migrations (off by default — useful in CI)
StrongMigrations.check_down = true

# ANALYZE after adding an index (keeps planner stats fresh)
StrongMigrations.auto_analyze = true
```

> strong_migrations does NOT detect dangerous **backfills**. It catches structural DDL, but a large
> unthrottled `UPDATE` inside a transaction is not blocked — apply the `disable_ddl_transaction!` +
> `in_batches` pattern yourself (see `safe-sequences.md` → Backfilling Data).

A given project may configure only a subset of these (e.g. just `lock_timeout`/`statement_timeout`) and
may add custom checks or `ActiveRecord::Migration` overrides. Read the project's initializer before
assuming a default is in force.

## The safety_assured escape hatch

```ruby
safety_assured { remove_column :users, :legacy_field, :string }
```

Not a shortcut. It exists for cases where you've completed the multi-step sequence and strong_migrations
lacks the context (e.g. "this column is already in `ignored_columns` in all deployed code"). Always
leave a comment explaining *why* it's safe:

```ruby
# safety_assured: no deployed code reads or writes this table — renaming is safe
safety_assured { rename_table :old_name, :new_name }
```

## Reviewing a migration for safety

When asked to review a migration, check:

1. Removes or renames a column/table? → needs `ignored_columns` + multi-deploy.
2. Adds an index without `algorithm: :concurrently`? → needs CONCURRENTLY + `disable_ddl_transaction!`.
3. Adds a foreign key without `validate: false`? → needs the 2-migration split.
4. Adds a check constraint without `validate: false`? → same.
5. Sets NOT NULL via `change_column_null`? → needs the check-constraint approach.
6. Backfills inside a transaction? → needs `disable_ddl_transaction!` + `in_batches`.
7. Changes a column type? → confirm it's a safe widening; otherwise expand/contract.
8. Adds a column with a volatile default (function call)? → add, then set default separately.
9. Uses `disable_ddl_transaction!` with more than one statement? → split into separate migrations.

**Fastest check:** if the project has strong_migrations installed, run `rails db:migrate` against a test
DB — it raises a descriptive error for any unsafe operation and tells you exactly what to do.
