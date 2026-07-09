# Setup & Global Configuration

## Installing

ActiveAdmin is a Rails Engine layered onto an existing app. Optional integrations: Devise (auth),
CanCanCan or Pundit (authorization), Draper (decorators).

```ruby
gem 'activeadmin'
gem 'devise'      # optional — auth
gem 'cancancan'   # optional — authorization
gem 'draper'      # optional — decorators
gem 'pundit'      # optional — authorization
```

```sh
bundle install

rails g active_admin:install            # generates AdminUser (Devise-backed)
rails g active_admin:install User        # use an existing user class instead
rails g active_admin:install --skip-users # no user model / skip Devise entirely
rails g active_admin:install --use_webpacker

rails db:migrate
rails db:seed
rails server
```

Visit `/admin`. Default seeded credentials: `admin@example.com` / `password`.

Generates: `app/admin/dashboard.rb`, `app/assets/javascripts/active_admin.js`,
`app/assets/stylesheets/active_admin.scss`, `config/initializers/active_admin.rb`, plus the
routes mount and AdminUser migration/seed (conventionally `ActiveAdmin.routes(self)` in
`routes.rb` — this exact line isn't spelled out on the install page, but it's the standard engine
mount).

Register a model as an admin resource:

```sh
rails generate active_admin:resource Post   # → app/admin/post.rb
```

Regenerate assets after a gem upgrade:

```sh
rails generate active_admin:assets
```

**Asset pipeline options** — Sprockets is the default; Webpacker and Vite are supported
alternatives (`rails g active_admin:webpacker`, or for Vite: `yarn add @activeadmin/activeadmin@^3`).

## `config/initializers/active_admin.rb`

Everything hangs off:

```ruby
ActiveAdmin.setup do |config|
  # ...
end
```

`config.namespace :name do |ns| ... end` scopes a block of the same setters to one namespace —
each namespace can override the top-level defaults independently. Per-resource, most of these
same settings are also assignable inside `ActiveAdmin.register Model do ... end` via `config.x =`
(see [registering-resources.md](registering-resources.md)).

### Authentication

```ruby
config.authentication_method = :authenticate_admin_user!   # before_action run to authenticate
config.current_user_method   = :current_admin_user          # returns the signed-in user

# disable auth entirely:
config.authentication_method = false
config.current_user_method   = false
```

Gotcha: an existing `ApplicationController` `before_action` runs *instead of* this setting — see
[gotchas.md](gotchas.md#authorization).

### Authorization

```ruby
config.authorization_adapter = "OnlyAuthorsAuthorization"   # custom adapter class name/const
config.authorization_adapter = ActiveAdmin::CanCanAdapter
config.authorization_adapter = ActiveAdmin::PunditAdapter

config.on_unauthorized_access = :access_denied   # controller method to handle CanCan::AccessDenied
config.cancan_ability_class   = "MyCustomAbility"
```

Settable per-namespace too (`ns.authorization_adapter = "AdminAuthorization"`). Full adapter
writing/wiring in [arbre-decorators-authorization.md](arbre-decorators-authorization.md).

### Site title / branding

```ruby
config.site_title       = "My Admin Site"
config.site_title_link  = "/"
config.site_title_image = "site_image.png"                          # from app/assets/images
config.site_title_image = "https://.../logo.png"                    # or a full URL
config.site_title_image = ->(context) { context.current_user.company.logo_url }  # dynamic, per-request
```

### I18n / localization

```ruby
config.localize_format = :short   # I18n date/time format key used for rendering. Default: :long
```

Labels/titles are otherwise translated through standard Rails locale files (e.g. renaming action
labels — see [registering-resources.md](registering-resources.md#renaming)).

### Namespaces

```ruby
ActiveAdmin.setup do |config|
  config.site_title = "My Default Site Title"

  config.namespace :admin do |admin|
    admin.site_title = "Admin Site"
  end

  config.namespace :super_admin do |super_admin|
    super_admin.site_title = "Super Admin Site"
  end
end
```

Constrain a namespace's mount (e.g. multi-tenant by domain):

```ruby
config.namespace :site_1 do |admin|
  admin.route_options = { path: :admin, constraints: ->(request){ request.domain == "site1.com" } }
end
```

### Load paths

```ruby
config.load_paths = [File.join(Rails.root, "app", "ui")]   # default: app/admin
```

### Comments

```ruby
config.comments = false                                    # disable globally
admin.comments  = false                                    # disable per-namespace
config.comments_registration_name = 'AdminComment'         # resource name comments register under
config.comments_order = 'created_at ASC'
config.comments_menu  = false
config.comments_menu  = { parent: 'Admin', priority: 1 }
```

### Utility navigation (top-right nav, e.g. logout link)

```ruby
admin.build_menu :utility_navigation do |menu|
  menu.add label: "ActiveAdmin.info", url: "https://www.activeadmin.info",
                                      html_options: { target: "_blank" }
end
```

The same `build_menu` mechanism (without `:utility_navigation`) builds the main sidebar menu's
parent items — see [registering-resources.md](registering-resources.md#menu).

### Footer

```ruby
config.footer = "MyApp Revision v1.3"
```

### Filters

```ruby
config.filters = false   # disable the filter sidebar globally (also settable per-namespace/resource)
```

### Scopes / sort order

```ruby
config.sort_order = 'name_asc'   # default sort applied when a resource doesn't set its own
```

### Pagination

```ruby
config.default_per_page = 30   # global default; override per-resource with config.per_page
config.paginate = false        # disable pagination entirely (global or per-resource)
```

### Batch actions

```ruby
config.batch_actions = false          # disable globally
admin.batch_actions   = false         # disable per-namespace
```

### Download links (CSV/XML/JSON/PDF)

```ruby
config.download_links = false
config.download_links = [:csv, :xml, :json, :pdf]
config.download_links = proc { current_user.can_view_download_links? }
```

`:pdf` only adds the link — you still implement PDF generation yourself.

### CSV options

```ruby
config.csv_options = { col_sep: ';' }
config.csv_options = { force_quotes: true }
config.disable_streaming_in = ['development', 'staging']   # CSV streams by default; see gotchas.md
```

### Not documented on any fetched ActiveAdmin doc page

The following are referenced informally in the wild but their exact syntax/defaults were **not**
present on any page fetched for this skill — verify against the gem source/CHANGELOG before
relying on them: favicon configuration, `config.meta_tags`, `config.root_to` /
`config.default_namespace`, logout link path/method customization, `register_stylesheet` /
`register_javascript`, view factory customization.

## Version note

This skill targets **ActiveAdmin 3.x** — the current stable line (3.5.x) and what's actually
deployed (`crm-web` runs `activeadmin 3.5.0`). ActiveAdmin 4.0 is beta as of this writing
(`4.0.0.beta22`) and is expected to change the asset pipeline (moving off Sprockets/Sass toward
Vite-based tooling) — installation/asset steps above may not apply to a 4.0 app. The resource DSL
(`register`/`index`/`show`/`form`/`filter`/`batch_action`/etc.) covered by the rest of this skill
appears unchanged in the 4.0 docs as of beta22, but re-verify against that app's actual installed
version before assuming parity.
