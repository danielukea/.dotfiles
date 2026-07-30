# Boot, Autoloading, and Configuration

## `load_defaults` is the behavior authority

`config.load_defaults X.Y` is **cumulative** and bumped **independently** of the gem, so it —
not `Gemfile.lock` — decides how the framework behaves.

Upgrade path: `bin/rails app:update` writes a `new_framework_defaults_X_Y.rb` with everything
commented out; uncomment gradually across deploys; bump `load_defaults` and delete the file last.

What flips at each version → [`versions.md`](versions.md).

## Zeitwerk

The rule is mechanical: **file path must match constant path.**
`app/models/card/closeable.rb` → `Card::Closeable`. A mismatch is a `NameError` at
autoload time, not at boot, so it can hide until the one request that touches it.

### Acronyms change constant names

```ruby
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.acronym "SQLite"
  inflect.acronym "IO"
end
```

Once `SQLite` is an acronym, `sqlite_adapter.rb` is expected to define `SQLiteAdapter` rather
than `SqliteAdapter`. **Adding an acronym can break existing autoloading** — do it early in a
project, and grep for affected constants when you do.

### `lib/` needs an ignore list

```ruby
config.autoload_lib ignore: %w[ assets tasks rails_ext ]
```

Anything in `lib/` that is not autoloadable Ruby — asset directories, rake tasks — or that you
`require` eagerly must be ignored. A directory that is both autoloaded *and* required will
double-define and blow up eager loading in production, which is the worst place to find out.

### Reloading has limits

Ruby cannot truly replace a class everywhere it is already referenced. Anything that captured a
class or an instance **at boot** keeps pointing at the old copy after a reload — the root cause
of "my change isn't taking effect until I restart."

Which leads to the single most common initializer bug:

## `to_prepare` vs `after_initialize`

| Hook                | Runs                      | Use for                                     |
| ------------------- | ------------------------- | ------------------------------------------- |
| `to_prepare`        | boot **and every reload** | anything touching app (reloadable) classes  |
| `after_initialize`  | boot **once**             | gem/framework config only                   |

Setting class-level state on an autoloaded class from `after_initialize` works exactly once:

```ruby
# ❌ resets to the default after the first code reload in development
config.after_initialize do
  Account.multi_tenant = true
end

# ✅
config.to_prepare do
  Notification.register_push_target(:web)
end
```

Because `to_prepare` runs repeatedly, **its block must be idempotent** — appending to an array
there without a guard grows it on every reload.

## `ActiveSupport.on_load` for framework classes

Referencing a framework class at initializer top level forces it to load early and fights
autoloading. Use the load hook:

```ruby
ActiveSupport.on_load(:active_record) do
  # self is ActiveRecord::Base — you're in the class body
end

ActiveSupport.on_load(:active_storage_attachment) do
  validate :blob_matches_record, on: :create

  private
    def blob_matches_record
    end
end
```

The block is evaluated **in the class body**, so `validate`, `private`, and method definitions
all work inline.

There are far more hooks than the documented handful — including per-adapter ones:
`:active_record`, `:active_record_postgresqladapter`, `:active_record_fixture_set`,
`:active_storage_blob`, `:action_text_rich_text`, `:active_job`, `:action_mailer`,
`:action_controller`, `:action_view`.

Nest them to mean "after **both** have loaded":

```ruby
ActiveSupport.on_load(:action_text_content) do
  ActiveSupport.on_load(:active_storage_blob) do
    # runs once both are ready
  end
end
```

## Initializers run in alphabetical order

`config/initializers/*.rb` load alphabetically. Never rely on another having run — and don't
rename files to force an order, because the next person won't know why.

`require_relative` it instead. `require` is idempotent, so this is safe even if the other file
already loaded:

```ruby
# config/initializers/database_role_logging.rb
require_relative "extensions"
```

## Eager loading only catches mistakes where it's enabled

```ruby
# config/environments/test.rb
config.eager_load = ENV["CI"].present?
```

Eager loading is on in production and off in development, so a naming or reference error can pass
every local test and fail at deploy. Turning it on in CI is the cheapest place to catch that —
without it, "works locally, breaks in production" autoload bugs are structurally invisible.

## Middleware

Insert at a **named position** rather than trusting the default:

```ruby
config.middleware.insert_after Rack::TempfileReaper, MyMiddleware
```

Middleware that establishes ambient state should **wrap** the downstream app in a block, not
assign and leave — otherwise the state leaks to the next request on that thread:

```ruby
def call(env)
  Current.with_account(account) { @app.call(env) }   # not Current.account = account
end
```

Make the conditional case explicit too: an "unauthenticated" or "no tenant" branch should enter a
deliberate empty state rather than inheriting whatever was there.

## `Current` attributes

`ActiveSupport::CurrentAttributes` setters are overridable, which is the right place to put
derivation — so callers assign one thing and get the rest:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :account, :session, :identity, :user

  def session=(value)
    super
    self.identity = value&.identity
  end

  def with_account(value, &) = with(account: value, &)
end
```

Two consequences:

- **Assignment order becomes load-bearing.** If `identity=` derives the user *scoped by account*,
  then `account` must be set first or the user resolves to nil, silently. Comment the ordering
  requirement where the assignment happens.
- Expose `with_*` **block** helpers and use those. `with` restores the previous value on exit,
  including on exception; a bare assignment does not.

Anything reading `Current` outside a request — a job, a console session, a rake task — must
establish it explicitly. See [`jobs.md`](jobs.md).

## Application configuration

Namespace app-specific config under `config.x`, with an ENV override:

```ruby
config.x.feature.enabled = ENV.fetch("FEATURE_ENABLED", "false") == "true"
```

Fail fast at boot on a missing hard dependency rather than at the first request that needs it:

```ruby
raise LoadError, "Please install libvips" unless defined?(Vips::LIBRARY_VERSION)
```

## Development strictness worth enabling

These turn silent bugs into loud ones and are almost always off by default:

```ruby
config.action_view.annotate_rendered_view_with_filenames = true
config.action_controller.raise_on_missing_callback_actions = true
config.active_record.verbose_query_logs = true
config.active_job.verbose_enqueue_logs = true
config.active_support.disallowed_deprecation = :raise
```

`raise_on_missing_callback_actions` catches a `before_action only: :typo` — otherwise that filter
simply never runs, forever, with no error.
