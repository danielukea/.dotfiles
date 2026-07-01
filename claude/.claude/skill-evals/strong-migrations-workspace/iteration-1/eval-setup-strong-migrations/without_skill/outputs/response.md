# Setting up `strong_migrations` to catch unsafe migrations in CI

`strong_migrations` works by raising an error at migration runtime whenever it detects a potentially-unsafe operation. To get it to "catch" things in CI, the trick is to actually **run your migrations in CI against a database** — when an unsafe operation is detected, the migration raises, the CI step exits non-zero, and the build fails before the code can ever reach production.

Here's the full setup.

## 1. Add the gem

```ruby
# Gemfile
gem "strong_migrations"
```

```bash
bundle install
```

Then generate the initializer (this also creates a `start_after` setting so it ignores all your existing migrations):

```bash
bin/rails generate strong_migrations:install
```

This creates `config/initializers/strong_migrations.rb`.

## 2. Configure the initializer

```ruby
# config/initializers/strong_migrations.rb

StrongMigrations.start_after = 20240101000000

# Set this to your target production Postgres version
StrongMigrations.target_version = 16  # e.g. Postgres 16

# Fail fast if a migration takes a lock too long
StrongMigrations.lock_timeout = 10.seconds
StrongMigrations.statement_timeout = 1.hour
```

`target_version` matters: adding a column with a default is safe on Postgres 11+, and certain index/constraint operations behave differently across versions.

## 3. How it actually catches things

By default, `strong_migrations` raises in **all environments** when it sees a dangerous operation. So as long as your CI pipeline runs the migrations against a real database, an unsafe migration will blow up the build.

## 4. The CI step

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  migrations:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: myapp_test
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready --health-interval 10s
          --health-timeout 5s --health-retries 5
    env:
      RAILS_ENV: test
      DATABASE_URL: postgres://postgres:postgres@localhost:5432/myapp_test
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Run migrations
        run: bin/rails db:create db:migrate
```

## 5. The escape hatch

```ruby
class RemoveSomeColumn < ActiveRecord::Migration[7.1]
  def change
    safety_assured { remove_column :users, :legacy_field }
  end
end
```

`safety_assured` is intentionally visible in the diff, so a reviewer sees that someone deliberately bypassed the check. Use it only when you've consciously verified the operation is safe.

## Summary

1. `gem "strong_migrations"`, `bundle install`.
2. `bin/rails generate strong_migrations:install` — set `start_after` + `target_version`.
3. CI runs `bin/rails db:create db:migrate` against real Postgres. Unsafe migration raises → build fails.
4. Use `safety_assured { ... }` only for reviewed, genuinely-safe exceptions.
