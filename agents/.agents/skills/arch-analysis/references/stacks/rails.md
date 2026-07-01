# Stack Adapter: Ruby on Rails

Patterns and signals specific to Rails apps. Loaded by every lens once the
stack is detected.

## Coupling traps

- **`has_many` chains 4+ deep**: `Account → Workspace → Project → Task →
  Comment`. Querying through the chain creates implicit transactional and
  authorization coupling. Look for `Account.workspaces.projects.tasks.comments`-style
  reaches.
- **Concerns included in 10+ classes**: god mixin. Grep
  `grep -rn 'include [A-Z]' app/ | awk '{print $NF}' | sort | uniq -c | sort -rn`.
- **Cross-controller method calls**: a controller calling another
  controller's action or private helper is a layer violation.
- **`ApplicationRecord` / `ApplicationController` as god classes**:
  count methods. >20 is a smell.
- **`Rails.application.config` reads in models / services**: pulled
  configuration into the wrong layer.

## Complexity hotspots

Run **Skunk** (preferred) — it computes StinkScore = complexity × (1 − coverage):

```bash
bundle exec skunk app/                          # whole app
bundle exec skunk app/ --sort stink_score        # ranked
bundle exec skunk -b main                        # branch comparison
```

Skunk requires SimpleCov data in `coverage/.resultset.json`. Run the test
suite first if it's not there.

Also useful:

```bash
bundle exec rubocop --only Metrics --format json   # method/class metrics
bundle exec reek app/                              # code smells (feature envy, etc.)
bundle exec flog app/ --all                        # ABC complexity per method
bundle exec flay app/                              # structural duplication
```

Exclude `db/migrate/` from churn analysis — every commit is a new file by
construction.

## Extensibility traps

### Callback chains
A model with 8 `before_save` / `after_commit` hooks creating side effects
across aggregates is a classic Rails extensibility hazard. Side effects
become implicit, ordering-sensitive, and hard to test in isolation.

```bash
grep -rn 'before_\|after_\|around_' app/models/ | wc -l
```

If a single model has 5+ callbacks, that's a finding. Connascence form: CoE
(execution order) at locality 1–3 (inside the class) but the *effects* fan
out across slices.

### Polymorphic + STI combinations
STI itself is fine. Polymorphism (`belongs_to :owner, polymorphic: true`)
is fine. *Together*, they create a 2-D type matrix where each combination
needs its own mental model. Look for tables with both `type` and
`*_type` columns.

### `acts_as_*` shotgunning
Each `acts_as_paranoid`, `acts_as_taggable`, `acts_as_list` adds methods,
columns, and lifecycle hooks. Five `acts_as_*` on one model is invisible
behavior accumulation.

### Service-object depth
A service that instantiates 3+ other services in its `call` method has
become a controller. Extract a coordinator, or push the dependencies into
the constructor.

### Form-model / decorator duplication
`app/form_models/`, `app/decorators/`, `app/presenters/` —
each layer often re-implements field transformations the others already
do. Watch for the same calculation appearing in a model, a serializer, and
a presenter (CoA across-modules).

## Vertical slicing in Rails

### App-folder namespacing
The most common Rails approach: keep the `app/{models,services,controllers,…}`
layer structure but namespace consistently within each layer.

```
app/services/notifications/send.rb
app/services/notifications/build_payload.rb
app/models/notifications/digest.rb
app/javascript/notifications/components/Inbox.tsx
```

A slice is "real" only if the namespacing is consistent across layers —
i.e., `Notifications::*` exists in models, services, controllers, jobs,
serializers, *and* the frontend.

### Rails Engines
For larger slices: `engines/billing/` is a self-contained Rails app. The
Engine's `routes.rb` and `engine.rb` are the public API. Consider when a
slice has its own DB tables, jobs, mailers, and would be deployable
standalone.

### Packwerk
The modern Shopify-style approach for modular monoliths.

```bash
bin/packwerk validate          # config health
bin/packwerk check             # runtime violations
find . -name 'package.yml' -path '*/packs/*'   # discover packs
```

If `packwerk.yml` exists, this is the authoritative slicing source — use
its `dependencies:` lists as the slice graph. If it doesn't exist, suggest
introducing it as a way to *make existing slicing observable*.

### Concern direction discipline
The Page-Jones rule applied to concerns:

✓ **Healthy:** `Notifications::Sendable` lives in the Notifications slice;
other slices' models include it; the concern only calls into Notifications-
slice code.

✗ **Diagonal:** A concern in slice A calls into slice B which is included
by slice C which imports back into slice A. Stitches three slices.

Find concerns that import models from another slice — that's the diagonal:

```bash
grep -rn 'class\|module' app/models/concerns/ -A 20 | grep -E 'User\.|Account\.|Workspace\.'
```

## Contract surface

- **Routes**: `bin/rails routes`. Versioned paths (`/v2/`)? Deprecation
  markers? `respond_to` blocks specifying multiple formats?
- **Serializers**: `app/serializers/` (ActiveModel::Serializer, Blueprinter,
  jsonapi-serializer, Alba) — the wire format. Schema-validated anywhere?
- **Jobs**: `app/jobs/`. Each `perform` signature is a queue contract.
  Renames break queued jobs in flight.
- **Pub/sub**: `ActiveSupport::Notifications.instrument` calls — implicit
  consumers.

## Variation points

### Healthy
- Pundit policies (`app/policies/`)
- Strategy classes (`app/strategies/`, often paired with a `for` factory)
- Flipper / LaunchDarkly / Rollout flags
- DB enum columns *with* a translation mechanism (i18n keys, helper)
- ActiveSupport::Concern modules with a clear `included do` block

### Dirty
- `case obj.class.name when 'Foo' then ...` chains
- `if Rails.env.production?` in business logic
- Stale Flipper flags older than 6 months
- `current_user.role == 'admin'` repeated everywhere instead of a Role
  object

## Tools to probe for

```bash
bundle exec skunk --version 2>/dev/null
bundle exec rubocop --version 2>/dev/null
bundle exec brakeman --version 2>/dev/null
bundle exec reek --version 2>/dev/null
bundle exec flog --version 2>/dev/null
bin/packwerk version 2>/dev/null
```
