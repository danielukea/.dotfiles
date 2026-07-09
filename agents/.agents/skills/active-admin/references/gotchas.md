# ActiveAdmin Gotchas

Every item here has bitten someone in production or is called out explicitly in the ActiveAdmin
docs/issue tracker. Grouped by where you'll run into it.

## Authorization

**`find_resource` override bypassing `scoped_collection` silently disables authorization.**
If you override `find_resource` and query the model directly instead of through
`scoped_collection`, any authorization adapter's scoping is skipped:

```ruby
controller do
  # BAD — bypasses scoped_collection, so CanCan/Pundit scoping never applies
  def find_resource
    Post.where(id: params[:id]).first!
  end

  # GOOD — inherits whatever scoping scoped_collection applies
  def find_resource
    scoped_collection.where(id: params[:id]).first!
  end
end
```

**Ransack denies filtering by default.** Since Ransack's authorization-conscious release, any
`filter :attr` on a model attribute is silently denied unless it's on that model's
`ransackable_attributes` allowlist. A filter that "does nothing" is almost always this — add the
attribute to `ransackable_attributes` on the model (per Ransack's own authorization guide), not
in ActiveAdmin.

**Pundit + batch actions needs `destroy_all?`.** To use ActiveAdmin's default `:destroy` batch
action under the Pundit adapter, your policy class must define a `destroy_all?` method — Pundit's
default policy doesn't have one, so batch destroy silently fails authorization otherwise.

**Pundit verification callbacks conflict with ActiveAdmin's own controllers.** Pundit's
`after_action :verify_authorized` / `verify_policy_scoped` fire on ActiveAdmin's controllers too
unless excluded:

```ruby
class ApplicationController < ActionController::Base
  include Pundit
  after_action :verify_authorized, except: :index, unless: :active_admin_controller?
  after_action :verify_policy_scoped, only: :index, unless: :active_admin_controller?

  def active_admin_controller?
    is_a?(ActiveAdmin::BaseController)
  end
end
```

**`ApplicationController` `before_action` callbacks take precedence over `config.authentication_method`.**
`ActiveAdmin::BaseController` inherits from `ApplicationController`. If `ApplicationController`
already has a `before_action :some_auth_method`, that runs *instead of* whatever you set as
`config.authentication_method` — the config setting doesn't override an existing callback, it's
only consulted where nothing else already authenticates the request.

## Strong Parameters

**Array-valued fields (HABTM, multi-select) need an explicit empty-array permit.** Any field that
can submit multiple values must be permitted as `attr_ids: []`, not just `:attr_ids` — otherwise
Rails silently strips the param:

```ruby
permit_params :title, :content, :publisher_id, role_ids: []
```

**Nested attributes need `:id` and `:_destroy` permitted, or editing/removing existing children breaks.**

```ruby
permit_params :title, tags_attributes: [:id, :name, :_destroy]
```

**On a `belongs_to` nested resource, declare `permit_params` *after* `belongs_to`.** Declaring it
first has been reported to not pick up the parent scoping correctly.

**Use `permitted_params`, not raw `params`, in controller overrides.** `permit_params` generates a
`permitted_params` method — reading `params[:post]` directly in an overridden `create`/`update`
bypasses the whitelist entirely:

```ruby
controller do
  def create
    @post = Post.new(permitted_params[:post])  # correct
  end
end
```

## Decorators

**Forms are NOT decorated by default.** `decorate_with` decorates index/show, but the form
builder gets the plain model unless you opt in:

```ruby
form decorate: true do |f|
  # ...
end
```

**A custom (non-Draper) decorator needs `to_param` delegated, or `show`/`edit`/`destroy` links 404.**
Any action that builds a URL with the record (`edit_admin_post_path(post)`) calls `to_param` on
whatever object it's given — a plain decorator that only delegates *some* methods will silently
break routing unless `to_param` is explicitly forwarded:

```ruby
class PostDecorator
  delegate_missing_to :post
  delegate :to_param, to: :post
end
```

**A custom decorator needs `decorated?` and `model` for the Comments feature to work.**

## CSV Export

**CSV export is a formula-injection vector if it includes untrusted user data.** A cell starting
with `=`, `+`, `-`, or `@` can execute a formula when opened in a spreadsheet app. Sanitize/escape
user-provided fields before they land in a CSV column, especially free-text fields.

**CSV streams by default — this disables exception debugging in development.** Because the
response streams as it's generated, a mid-stream exception doesn't surface the normal Rails error
page. Turn streaming off in the environments where you need to debug:

```ruby
config.disable_streaming_in = ['development', 'staging']
```

**Listing `:pdf` in `download_links` does not generate a PDF for you.** ActiveAdmin only adds the
UI link/route — you still have to implement PDF rendering yourself (WickedPDF, PDFKit, etc.).

## Batch Actions

**The entire index view is one `<form>`.** All batch-action controls submit through a single form
wrapping the whole index. Embedding another form that uses PUT/PATCH inside a custom index block
can produce routing conflicts — use POST for anything nested, or move it to its own page/member action.

## Assets & CSS

**Asset prefix colliding with ActiveAdmin's namespace breaks sessions and flash entirely, silently.**
If `config.assets.prefix` (Sprockets) matches ActiveAdmin's mount namespace (default `/admin`),
Sprockets prevents the session from being committed — flash messages stop working and nothing
written to session persists. Keep them different.

**`require_tree` in your app's own stylesheet manifest can let ActiveAdmin's CSS override your
app's styles.** Remove `require_tree` from manifests that also pull in `active_admin.scss`.

**AA v3's SCSS targets an older Sass spec — expect `lighten()`/color-function deprecation warnings
under Node-based build tools** (esbuild, webpacker, vite via `sassc`/dart-sass). Workaround: pass
the `quietDeps` option to the Sass compiler.

**Helpers don't hot-reload in development** — a known, still-open upstream issue. Restart the
server after changing a helper used inside ActiveAdmin views.

**`config.action_controller.include_all_helpers = false` means ActiveAdmin won't get your
app helpers automatically** — include them explicitly:

```ruby
ActiveAdmin::BaseController.class_eval { helper ApplicationHelper }
# or, per resource:
ActiveAdmin.register User do
  controller { helper UserHelper }
end
```

## Naming Conflicts

**A model class method named `search` collides with Ransack's `search`** (Ransack is an
ActiveAdmin dependency and defines `Model.search` for filtering). If another gem (tire/retire,
elasticsearch-rails, Sunspot) also defines `search`, use that gem's namespaced method instead of
the bare class method: `Model.tire.search`, `Model.__elasticsearch__.search`, `Model.solr_search`.

**`will_paginate` and Kaminari (ActiveAdmin's paginator) both try to define a `page` method** on
`Array`/`ActiveRecord::Relation`. If your app already has `will_paginate`, rename Kaminari's:

```ruby
# config/initializers/kaminari.rb
Kaminari.configure { |config| config.page_method_name = :per_page_kaminari }
```
