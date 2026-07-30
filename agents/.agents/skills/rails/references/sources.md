# Sources

Canonical references, each annotated with what it is authoritative **for** — not a general
description. Fetch current docs rather than relying on recall, especially for anything
version-dependent.

## Version-pinned lookups (the most useful trick here)

Both of these accept a version segment, and bisecting across them is the fastest way to answer
"when did this method appear?":

- `https://guides.rubyonrails.org/v8.0/configuring.html`
- `https://api.rubyonrails.org/v7.0/classes/ActiveRecord/QueryMethods/WhereChain.html`

Pin the version whenever the difference between 8.0 and 8.1 semantics matters.

## Guides

| URL                                                                    | Authoritative for                                                                                               |
| ---------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| [configuring](https://guides.rubyonrails.org/configuring.html)          | **the `load_defaults` version→flag tables** — the best source for "what flips at 8.0 vs 8.1"                     |
| [active_record_querying](https://guides.rubyonrails.org/active_record_querying.html) | the `includes`/`preload`/`eager_load` distinction, `where.missing`/`where.associated`, `find_each`, `pluck`/`pick` |
| [active_record_callbacks](https://guides.rubyonrails.org/active_record_callbacks.html) | callback ordering, transaction callbacks, and the canonical **list of methods that skip callbacks**             |
| [association_basics](https://guides.rubyonrails.org/association_basics.html) | association options, `dependent:`, `touch:`, `counter_cache`, delegated types                                   |
| [autoloading_and_reloading_constants](https://guides.rubyonrails.org/autoloading_and_reloading_constants.html) | Zeitwerk in Rails, `autoload_lib(ignore:)`, reloading and stale-object semantics, `to_prepare` idempotency |
| [active_job_basics](https://guides.rubyonrails.org/active_job_basics.html) | job continuations, and the official guidance on `enqueue_after_transaction_commit`                              |
| [caching_with_rails](https://guides.rubyonrails.org/caching_with_rails.html) | fragment and Russian-doll caching, `cache_key_with_version`                                                    |
| [routing](https://guides.rubyonrails.org/routing.html)                  | resourceful routing, the "nest one level deep" guidance, `direct`/`resolve`                                      |
| [security](https://guides.rubyonrails.org/security.html)                | CSRF model, session security, open-redirect guidance                                                            |
| [upgrading_ruby_on_rails](https://guides.rubyonrails.org/upgrading_ruby_on_rails.html) | the `bin/rails app:update` + `new_framework_defaults_X_Y.rb` incremental workflow                              |
| [action_controller_advanced_topics](https://guides.rubyonrails.org/action_controller_advanced_topics.html) | `allow_browser` and forgery-protection config                                                    |
| [error_reporting](https://guides.rubyonrails.org/error_reporting.html)   | the `Rails.error` API                                                                                           |

Gaps worth knowing: **`rate_limit` is not documented in any guide** — API docs only. Neither is
the Rails 8 authentication generator; read the generator templates in `rails/rails` instead of a
blog post.

## Edge (unreleased)

- [edgeguides.rubyonrails.org](https://edgeguides.rubyonrails.org/) — documents `main`. Warns that
  WIP pages may be incomplete or wrong.
- [8.2 release notes](https://edgeguides.rubyonrails.org/8_2_release_notes.html) — the **only**
  place 8.2 notes exist; the stable-guides URL for it does not exist.
- [edge configuring](https://edgeguides.rubyonrails.org/configuring.html) — the
  `load_defaults 8.2` flag table.

## API and release notes

- [api.rubyonrails.org](https://api.rubyonrails.org/) — class URLs follow
  `/classes/<Namespace>/<Class>.html`. The definitive source for what a method does, and (via the
  version-pinned form) when it appeared.
  - `ActiveRecord/Relation.html` — the verbatim statements that `update_all` skips callbacks,
    validations, **and `updated_at`**, and that `delete_all` ignores `dependent:` rules.
  - `ActiveRecord/Transactions/ClassMethods.html` — nested transactions join the parent unless
    `requires_new:`; identical callbacks are deduplicated; transactions don't span connections.
  - `ActionController/Parameters.html` — `expect` / `expect!`.
- [8.0 release notes](https://guides.rubyonrails.org/8_0_release_notes.html) ·
  [8.1 release notes](https://guides.rubyonrails.org/8_1_release_notes.html)
- [rubyonrails.org/maintenance](https://rubyonrails.org/maintenance) — support and EOL windows per
  series. Check this rather than trusting a remembered version number.

## Queue, cache, deploy

- [solid_queue](https://github.com/rails/solid_queue) — `config/queue.yml`, `config/recurring.yml`
  (Fugit cron), `limits_concurrency`, `FOR UPDATE SKIP LOCKED`. Default from 8.0.
- [solid_cache](https://github.com/rails/solid_cache) — `config/cache.yml`, `max_age`,
  `max_entries`, encryption.
- [sidekiq best practices](https://github.com/sidekiq/sidekiq/wiki/Best-Practices) — pass ids not
  records; design for idempotency, because jobs re-run. Note it does **not** cover the
  transaction-commit race.
- [kamal-deploy.org](https://kamal-deploy.org/) — deployment configuration and commands.

## Gotchas worth citing directly

| Source                                                                                                                   | The specific claim it's the best citation for                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| [active_record_callbacks §Transaction Callbacks](https://guides.rubyonrails.org/active_record_callbacks.html)             | `after_commit` makes different guarantees than `after_save` — an exception there does **not** roll back, and it skips remaining callbacks |
| [ActiveRecord::Relation API](https://api.rubyonrails.org/classes/ActiveRecord/Relation.html)                              | the definitive rebuttal to `update_all` "optimizations"                                                                          |
| [isolator](https://github.com/palkan/isolator)                                                                            | why no background job or HTTP call belongs inside a DB transaction — including the implicit `after_create` case                  |
| [Evil Martians — silenced Ruby exceptions](https://evilmartians.com/chronicles/the-silence-of-the-ruby-exceptions-a-rails-postgresql-database-transaction-thriller) | a rescued exception inside a transaction leaves **Postgres** aborted; later statements fail far from the cause |
| [thoughtbot — It's About Time Zones](https://thoughtbot.com/blog/its-about-time-zones)                                     | the explicit avoid/use table: `Time.now`/`Date.today`/`Time.parse` → `Time.current`/`Date.current`/`Time.zone.parse`             |
| [Zeitwerk](https://github.com/fxn/zeitwerk)                                                                                | the file↔constant naming law, reload constraints, and why `require` for app code is wrong                                        |
| [autoloading guide §Reloading](https://guides.rubyonrails.org/autoloading_and_reloading_constants.html)                    | Ruby can't truly reload a class everywhere it's referenced — the root cause of stale-constant bugs                               |
| [strong_migrations](https://github.com/ankane/strong_migrations)                                                           | the unsafe-migration catalog (cross-reference; `strong-migrations` skill owns this)                                             |

## Design writing

- [Vanilla Rails is plenty](https://dev.37signals.com/vanilla-rails-is-plenty/) — the case for rich
  domain models over a service layer.
- [Good concerns](https://dev.37signals.com/good-concerns/) — the test for whether a concern
  represents a real trait rather than a bag of methods.
- [The Rails Doctrine](https://rubyonrails.org/doctrine) — convention over configuration, and the
  reasoning behind the conventions this skill describes.
- [rubocop-rails-omakase](https://github.com/rails/rubocop-rails-omakase) — the default style
  config in new Rails apps since 7.2. Note that
  [rails.rubystyle.guide](https://rails.rubystyle.guide/) is community-maintained, self-describes
  as "Rails 4.2+", and conflicts with omakase in places.
