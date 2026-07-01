# Setting Up strong_migrations to Catch Unsafe Migrations in CI

The core idea: the [strong_migrations gem](https://github.com/ankane/strong_migrations) checks migrations **at runtime** — when you run `rails db:migrate`, it inspects each pending migration and *raises a descriptive error before the unsafe operation executes*, telling you exactly how to rewrite it safely. So your CI gate is simply: **run your migrations against a database in CI**. Any unsafe migration fails the build before it can ever reach production.

Here's the full setup.

## 1. Add and install the gem

```ruby
# Gemfile
gem "strong_migrations"
```

```bash
bundle install
rails generate strong_migrations:install
```

The generator creates a configured initializer at `config/initializers/strong_migrations.rb`.

## 2. Configure the initializer

```ruby
# config/initializers/strong_migrations.rb

# Skip historical migrations that already ran in production.
# Set this to the timestamp of your most recent migration so strong_migrations
# only checks NEW migrations going forward (otherwise it flags old migrations
# that are already live and can't be changed).
StrongMigrations.start_after = 20250101000000

# Auto-apply safe patterns for indexes, foreign keys, and check constraints
# (e.g. adds algorithm: :concurrently and validate: false automatically).
StrongMigrations.safe_by_default = true

# Prevent runaway lock waits in production.
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour

# Retry on lock timeout for busy tables.
StrongMigrations.lock_timeout_retries = 3
StrongMigrations.lock_timeout_retry_delay = 10.seconds

# Match your production Postgres major version so version-specific checks
# (e.g. whether a column type change rewrites the table) are accurate.
StrongMigrations.target_version = 16
```

A few notes:

- **`start_after`** is the most important first-time setting. Without it, strong_migrations will flag migrations you ran years ago. Set it to the timestamp of your latest existing migration.
- **`safe_by_default = true`** is highly recommended. It means strong_migrations doesn't just complain about unsafe index/FK/constraint additions — it automatically rewrites them into the safe form. You write `add_index :users, :email` and it transparently runs it concurrently outside a transaction.
- **`target_version`** must match production. Some operations are safe on newer Postgres but not older (e.g. adding a column with a constant non-null default is instant on PG 11+ but rewrites the whole table before that). Setting this wrong gives you false positives or false negatives.

## 3. Wire it into CI

This is the actual "gate." Your CI job needs a real database, then just runs the migrations. If any pending migration is unsafe, `rails db:migrate` exits non-zero and the build fails.

A minimal GitHub Actions example:

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  migrations:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16          # match production / target_version
        env:
          POSTGRES_PASSWORD: postgres
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost:5432

    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      # Build the schema WITHOUT replaying every migration. This loads
      # schema.rb so the DB matches the current committed schema.
      - name: Prepare database
        run: bin/rails db:create db:schema:load

      # THE GATE: run pending migrations. strong_migrations inspects each one
      # and fails the build on any unsafe operation.
      - name: Run migrations (strong_migrations gate)
        run: bin/rails db:migrate
```

Why `db:schema:load` first, then `db:migrate`:

- `db:schema:load` brings the test DB up to the *current* committed schema instantly (no migration replay).
- `db:migrate` then runs only the *new, pending* migrations on the PR branch — which are exactly the ones you want strong_migrations to check.

If your branch's `schema.rb` already includes the new migration (because the author ran it locally and committed the schema dump), `db:migrate` will have nothing pending. To reliably exercise the check, you want CI to run the migration itself. Two robust options:

- **Recommended:** load schema from the *base branch*, then `db:migrate` the PR's new migrations. Some teams instead drop `schema.rb` to the merge-base in CI before migrating.
- **Simpler alternative:** just run `bin/rails db:create db:migrate` from a fresh DB on every CI run. This replays all migrations from scratch. Combined with `start_after`, only the post-`start_after` migrations are actually checked, so it stays fast enough for most apps and is the most foolproof gate.

The simplest reliable gate is therefore:

```yaml
      - name: Run migrations from scratch (strong_migrations gate)
        run: bin/rails db:create db:migrate
```

Use the schema-load variant if full replay gets too slow.

## 4. What it catches (and what it tells the author)

When CI hits an unsafe migration, the build fails with a message that explains the danger *and* the safe rewrite. For example, adding an index normally:

```ruby
add_index :users, :email
```

…fails (without `safe_by_default`) with guidance to write:

```ruby
class AddIndexOnUsersEmail < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!  # required — CONCURRENTLY can't run inside a transaction

  def change
    add_index :users, :email, algorithm: :concurrently
  end
end
```

The operations it gates include:

| Operation | Why it's dangerous | Safe approach it points you to |
|-----------|--------|---------------|
| Remove column | AR caches columns; old code crashes | `ignored_columns` → deploy → then drop |
| Rename column / table | Old code writes to old name → data loss | Expand/contract over multiple deploys |
| Change column type | Table rewrite, full lock | Add new col → backfill → switch → drop old |
| Add column with non-null default (PG < 11) | Table rewrite | Add nullable → backfill → add constraint |
| Add index | Blocks writes for full build | `algorithm: :concurrently` + `disable_ddl_transaction!` |
| Add foreign key | ACCESS EXCLUSIVE on both tables | `validate: false` → validate in a separate migration |
| Add check constraint | Locks during row scan | `validate: false` → validate separately |
| Set NOT NULL via `change_column_null` | Locks during validation | NOT VALID check constraint → validate → set null false |
| Backfill in a transaction | Long-held lock | `disable_ddl_transaction!` + `in_batches` |

With `safe_by_default = true`, the index / foreign key / check constraint cases are rewritten for you automatically rather than failing.

## 5. The escape hatch — `safety_assured`

Some operations are genuinely safe in *your* specific context but strong_migrations can't know that (e.g. you've already added the column to `ignored_columns` in all deployed code, completed the multi-deploy sequence, and now you're dropping it). For those, wrap the operation:

```ruby
class RemoveOldColumnFromUsers < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_column :users, :legacy_field }
  end
end
```

**Treat this as a deliberate, reviewed exception — never a shortcut to silence the check.** Its presence in a diff is a signal for reviewers to confirm the multi-step sequence was actually followed. If people start sprinkling `safety_assured` to make CI green, the gate stops protecting you.

## Summary

1. `gem "strong_migrations"` + `rails generate strong_migrations:install`.
2. Configure the initializer: set `start_after` to your latest migration timestamp, enable `safe_by_default`, set `lock_timeout` / `statement_timeout`, and set `target_version` to your production Postgres major version.
3. In CI, stand up a Postgres service matching production and run `rails db:migrate` (or `db:create db:migrate` from scratch). An unsafe migration fails the build with an explanation and the safe rewrite.
4. Keep `safety_assured` for reviewed, genuinely-safe exceptions only.

That gives you a deterministic, automated gate: unsafe schema changes can't merge because they fail CI, and every failure comes with instructions for the safe multi-step alternative.
