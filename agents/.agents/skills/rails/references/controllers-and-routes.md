# Controllers and Routes

The measurements in `SKILL.md` come from here: 102 controllers, **one** non-CRUD action in
the entire application, median 21 lines. This file shows how that is achieved.

> The source app renders Turbo Streams. Response blocks below are normalized to
> `redirect_to` / `head :no_content` so the **shape of the action** is the lesson —
> substitute whatever your app's view layer uses.

## `ApplicationController` is a list of concerns

```ruby
class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include BlockSearchEngineIndexing
  include CurrentRequest, CurrentTimezone, SetPlatform
  include RequestForgeryProtection
  include TurboFlash, ViewTransitions
  include RoutingHeaders

  etag { "v1" }
  stale_when_importmap_changes
  allow_browser versions: :modern
end
```

Thirteen lines. No `before_action`, no `rescue_from`, no helper methods, no shared query
logic. Everything is a named concern that a subclass can reason about individually.

**Concern order is load-bearing.** `Authentication` must precede `Authorization`, because
`Authorization`'s `before_action` predicate reads the `Current.identity` that
`Authentication` populates. When order matters, say so in a comment — the next reader cannot
infer it.

_Source: fizzy — `app/controllers/application_controller.rb`._

## When an action isn't CRUD, add a resource

This is the single highest-leverage rule in the file. The temptation:

```ruby
# ❌ mixes mutation verbs into a resource controller; doesn't scale
resources :cards do
  post :close
  post :reopen
  post :gild
  post :pin
end
```

What Rails wants instead — each state becomes a **resource** whose `create`/`destroy` are the
transition:

```ruby
# ✅
resources :cards do
  scope module: :cards do
    resource :closure
    resource :goldness
    resource :pin
    resource :watch
    resource :triage
  end
end
```

`POST /cards/:card_id/closure` closes; `DELETE` reopens. Note **singular `resource`** — there
is only ever one closure per card, so there is no `index` and no `:id`. `scope module: :cards`
namespaces the controller classes (`Cards::ClosuresController`) without adding path segments.

### The payoff: a complete controller in 21 lines

```ruby
class Cards::GoldnessesController < ApplicationController
  include CardScoped

  def create
    @card.gild
    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end

  def destroy
    @card.ungild
    respond_to do |format|
      format.html { redirect_to @card }
      format.json { head :no_content }
    end
  end
end
```

What is **absent** is the point: no `@card` lookup (the concern supplies it), no params
method (there is nothing to permit), no authorization call (the scoped lookup already did
it), no validation branching (the model owns that). Two verbs delegating to two model verbs.

### Variations worth knowing

- **`create` without `destroy`.** If a transition is one-way, ship one action. A 14-line
  controller with only `create` is complete, not unfinished.
- **A transition that takes an argument is still `create`.** Scope the argument through the
  parent rather than reaching for strong params:

  ```ruby
  def create
    column = @card.board.columns.find(params[:column_id])
    @card.triage_into(column)
    redirect_to @card
  end
  ```

  One foreign key arriving as a bare scalar needs no `params.expect` ceremony — but it does
  need to be looked up **through the parent**, which is what makes it safe.

- **Add `show` when a client needs to validate a cache entry.** Use a sentinel for the
  absent state, since `fresh_when etag: nil` is meaningless:

  ```ruby
  def show
    fresh_when etag: @card.watch_for(Current.user) || "none"
  end
  ```

- **One gate for a privileged transition.** A single `before_action` predicate, not a policy
  class:

  ```ruby
  class Boards::PublicationsController < ApplicationController
    include BoardScoped
    before_action :ensure_permission_to_admin_board

    def create  = @board.publish
    def destroy = @board.unpublish
  end
  ```

## Scoping concerns are the authorization mechanism

```ruby
module CardScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_card, :set_board
  end

  private
    def set_card
      @card = Current.user.accessible_cards.find_by!(number: params[:card_id])
    end

    def set_board
      @board = @card.board
    end
end
```

The lookup starts from **a user-owned association**, so an inaccessible record is not "found
then denied" — it is never found. `find_by!` raises `RecordNotFound` → 404, which also avoids
leaking existence. Authorization is a property of the query, not a separate layer.

This is why policy objects are usually redundant: `Current.user.accessible_cards` already
encodes the rule, and it composes into every subsequent query.

**Where a codebase uses a policy gem** (Pundit, CanCan) with an `app/policies/` directory,
that is the established local pattern — follow it. See `## Precedence` in
[`SKILL.md`](../SKILL.md).

Scoping concerns also hold the small shared response helpers the controllers in a family
need, which is what keeps each controller at two methods.

_Source: fizzy — `app/controllers/concerns/card_scoped.rb`._

## Routes

A 263-line routes file with **one** non-CRUD action. The shape:

```ruby
Rails.application.routes.draw do
  root "events#index"

  namespace :account do
    resource  :cancellation, only: [ :create ]
    resource  :settings
    resources :exports, only: [ :create, :show ]
  end

  resources :boards do
    scope module: :boards do
      resources :accesses, only: :index
      resource  :publication
      resource  :entropy

      resources :columns do
        scope module: :columns do
          resources :cards, only: :index
        end
      end
    end
  end

  resources :cards do
    scope module: :cards do
      resource  :closure
      resource  :goldness
      resource  :pin
      resource  :watch

      resources :comments do
        resources :reactions, module: :comments
      end
    end
  end
end
```

Conventions in play:

- **`resource` (singular) for at-most-one** — no `index`, no `:id` segment.
- **`scope module:`** groups controllers into a namespace without adding path noise;
  `namespace` when you want the path segment too.
- **`only:` / `except:`** on nearly every collection — declare the actions that exist so the
  router documents the surface.
- **Nest one level.** A deeper need is a signal to route the child from its own top-level
  resource instead.
- `member` / `collection` blocks are rare. Reaching for one is usually the same signal as
  reaching for a custom action.

## Params

```ruby
params.expect(:email_address)                          # top-level scalar
params.expect signup: :email_address                   # nested single scalar
params.expect(card: [ :title, :description, :image ])  # nested list
```

`params.expect` (Rails **8.0**) replaces `require(...).permit(...)`. It is stricter about
shape: a String where a Hash was expected raises `ParameterMissing` (→ 400) rather than
producing a 500 deep in the stack. Keep the param method **private, at the bottom** of the
controller — or skip it entirely when there is nothing to permit.

## Responses

- `respond_to` with an explicit branch per format; `head :no_content` for a mutation an API
  client doesn't need a body for.
- **`redirect_to` after a successful mutation, `render` after a failed one** — re-rendering
  preserves the invalid object and its errors, and a redirect would discard them.
- Return `:unprocessable_entity` on a failed `create`/`update` so clients can distinguish
  invalid input from a server fault.
- HTTP caching — additive `etag {}`, per-action `fresh_when` — see
  [`views-and-helpers.md`](views-and-helpers.md).

## Error handling

Two layers, and they belong in different places:

- **Not found / not permitted** — let the scoped `find_by!` raise. Rails renders 404. Don't
  rescue it per-controller.
- **Domain failures** — a `rescue_from` in the base controller or a concern, not scattered
  `rescue` blocks inside actions.

In development, `config.action_controller.raise_on_missing_callback_actions = true` catches a
`before_action only:` naming an action that doesn't exist — a typo that otherwise fails
silently forever.
