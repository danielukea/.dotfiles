# Versions — what exists where

Feature-to-version recall is the single least reliable thing an LLM knows about Rails. Most APIs
that *feel* like "Rails 8" landed in 7.0–7.2. Before using an API whose availability matters,
check a **version-pinned** URL: `https://guides.rubyonrails.org/v8.0/…` and
`https://api.rubyonrails.org/v7.0/…` both work, and bisecting across them is the fastest way to
find when a method appeared.

## Two numbers, and they are not the same

| Question                        | Answer                                          |
| ------------------------------- | ----------------------------------------------- |
| Which code is installed?        | `Gemfile.lock`                                  |
| **How does the framework behave?** | **`config.load_defaults` in `config/application.rb`** |
| Which flips are partially adopted? | `config/initializers/new_framework_defaults_*.rb` |

`load_defaults` is cumulative and bumped independently of the gem. A Rails 8 app with
`load_defaults 7.0` behaves like 7.0. Read all three before concluding anything.

## Commonly misdated APIs

These are the ones to stop attributing to 8.x:

| API                                        | Actually landed in |
| ------------------------------------------ | ------------------ |
| `pick`                                     | 6.0                |
| `where.missing`                            | 6.1                |
| `enum :status, [...]` (positional syntax)  | 7.0                |
| `where.associated`                         | 7.0                |
| `load_async`                               | 7.0                |
| `sole` / `find_sole_by`                    | 7.0                |
| `encrypts` (Active Record encryption)      | 7.0                |
| `normalizes`                               | **7.1**            |
| `generates_token_for`                      | **7.1**            |
| `authenticate_by`                          | **7.1**            |
| `rate_limit`                               | **7.2**            |
| `allow_browser`                            | **7.2**            |
| `params.expect`                            | 8.0                |
| `ActiveJob::Continuable`                   | 8.1                |
| Structured event reporting (`Rails.event`) | 8.1                |
| Local CI (`config/ci.rb`, `bin/ci`)        | 8.1                |
| `has_many ..., deprecated: true`           | 8.1                |

`load_async` needs `config.active_record.async_query_executor` configured to actually run
concurrently — otherwise it silently degrades to a foreground query.

## Removed but still plausible-looking

Code that reads as correct and no longer is.

### Rails 8.0

- **`enum status: [:active, :archived]` — removed.** Only `enum :status, [...]` parses. This is
  the most common thing generated Rails code gets wrong on 8.x.
- **`return` / `break` out of a `transaction` block now commits.**
  `commit_transaction_on_non_local_return` was removed, so a non-local exit is no longer a
  rollback. Only a raise (or `ActiveRecord::Rollback`) rolls back. See
  [`transactions-and-callbacks.md`](transactions-and-callbacks.md).
- Singular association names no longer resolve in queries
  (`allow_deprecated_singular_associations_name` removed).
- `bin/rake stats` → `bin/rails stats`.

### Rails 8.1

- Symbol values for `enqueue_after_transaction_commit`, and the global
  `config.active_job.enqueue_after_transaction_commit`, are **removed** — see the trap below.
- Semicolon as a query-string separator; leading-bracket param names; multi-path routes.
- The built-in Sidekiq adapter moves to the `sidekiq` gem.
- `schema.rb` columns are dumped **alphabetically** — expect one large diff on the first migrate
  after upgrading.

## The `enqueue_after_transaction_commit` trap

Worth calling out separately because it **inverts silently** rather than raising.

| Rails | State                                                                        |
| ----- | ---------------------------------------------------------------------------- |
| 7.2   | introduced, accepting symbols                                                 |
| 8.0   | boolean `class_attribute`, `default: false`; symbols still work but warn; the global config is deprecated |
| 8.1   | symbols and the global config removed                                         |

On 8.0, `active_job/enqueue_after_transaction_commit.rb` maps `:never` → `false` and `:always` →
`true` through an explicit `case`, emitting a deprecation each time.

Once 8.1 removes that `case`, a leftover `:never` falls through to the `else` branch, which
returns the value unchanged — and **a Symbol is truthy in Ruby**. So
`self.enqueue_after_transaction_commit = :never` flips from *enqueue immediately* to *defer until
commit*: the opposite of its author's intent, with no error and no warning.

Grep for symbol assignments and convert them to booleans **before** upgrading.

## What flips at each `load_defaults`

### 8.0

- `active_support.to_time_preserves_timezone = :zone` — `to_time` now returns a Time in the
  **receiver's** zone. A silent data shift in any code calling `.to_time`.
  **This one must be set in `config/application.rb`**, not in a `new_framework_defaults`
  initializer: Active Support loads before initializers run (rails/rails#54015).
- `Regexp.timeout = 1` — long-running regexes raise instead of hanging.
- `action_dispatch.strict_freshness = true` — ETag preferred over Last-Modified.

### 8.1

- **`raise_on_missing_required_finder_order_columns = true`** — `first`/`last`/`find_nth` **raise
  `ActiveRecord::MissingRequiredOrderError`** on a relation with no `order`, no
  `implicit_order_column`, no `query_constraints`, and no primary key. Bites `has_many :through`
  join models and PK-less tables. Always order by a unique tiebreaker — see
  [`active-record.md`](active-record.md).
- `action_controller.escape_json_responses = false` — JSON responses no longer escape U+2028/2029.
  If you inline JSON into a `<script>` tag by hand, that is now an XSS/parse hazard.
- `action_controller.action_on_path_relative_redirect = :raise` — `redirect_to "foo/bar"` without
  a leading slash raises.
- `config.yjit = !Rails.env.local?` — YJIT off in development and test.

### 8.2 (unreleased — see below)

- Active Job enqueues after transaction commit **by default**.
- Header-based CSRF via `Sec-Fetch-Site`.
- **Enum negative scopes now include `nil`** — `Book.not_published` previously excluded only
  published rows and now also returns rows where the enum is null. A silent change in query
  results.
- `active_record.marshalling_format_version = 6.1` removed — move to `7.1` and flush caches
  *before* upgrading.

## Release status

As of **2026-07-30**:

- **8.1.3.1** — current stable.
- **8.0.5.1** — current 8.0 patch. 8.0 is in security-only maintenance.
- **8.2 has not shipped.** No 8.2.x gem exists — not alpha, not beta. It lives only on
  `rails/rails@main` as `8.2.0.alpha`.

Consequences for looking things up:

- `https://guides.rubyonrails.org/8_2_release_notes.html` **does not exist.** Use
  `https://edgeguides.rubyonrails.org/8_2_release_notes.html`.
- Edge guides document `main`, and warn that work-in-progress pages may be incomplete or wrong.
- A codebase tracking `rails/rails@main` is a **preview**, not a template. Anything drawn from one
  needs its version checked before being copied into an app on a released Rails.

Check the current numbers rather than trusting this section — `https://rubyonrails.org/maintenance`
is authoritative for support windows. See [`sources.md`](sources.md).
