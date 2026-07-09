# Registering & Customizing a Resource

```sh
rails g active_admin:resource Post   # → app/admin/post.rb
```

```ruby
ActiveAdmin.register Post do
  permit_params :title

  filter :title
  filter :created_at

  actions :all, except: []

  # index do ... end / show do ... end / form do |f| ... end — see their own reference files
end
```

## `permit_params` — strong parameters

```ruby
permit_params :title, :content, :publisher_id
```

Array-valued fields (HABTM, multi-select) **must** be permitted as an empty array, or Rails drops
the param — see [gotchas.md](gotchas.md#strong-parameters):

```ruby
permit_params :title, :content, :publisher_id, role_ids: []
```

Nested attributes (`accepts_nested_attributes_for`) — include `:id` and `:_destroy`:

```ruby
permit_params :title, :content, :publisher_id,
  tags_attributes: [:id, :name, :description, :_destroy]
```

Dynamic, computed at request time — return the array of permitted keys from a block:

```ruby
permit_params do
  params = [:title, :content, :publisher_id]
  params.push :author_id if current_user.admin?
  params
end
```

On a nested (`belongs_to`) resource, declare `permit_params` **after** `belongs_to`:

```ruby
ActiveAdmin.register Post do
  belongs_to :user
  permit_params :title, :content, :publisher_id
end
```

`permit_params` generates a `permitted_params` method. Use it — not raw `params` — in any
controller override:

```ruby
controller do
  def create
    @post = Post.new(permitted_params[:post])   # correct; params[:post] bypasses the whitelist
  end
end
```

## `actions` — enable/disable resource actions

```ruby
actions :all, except: [:update, :destroy]
```

## Renaming {#renaming}

```ruby
ActiveAdmin.register Post, as: "Article"       # → /admin/articles
ActiveAdmin.register Post, namespace: :today    # → /today/posts
ActiveAdmin.register Post, namespace: false     # → /posts
```

Rename generated action-item labels via locale (not a DSL call):

```yaml
en:
  active_admin:
    resources:
      offer:
        new_model: 'Make an Offer'
        edit_model: 'Change Offer'
        delete_model: 'Cancel Offer'
```

## `menu` {#menu}

```ruby
menu false                                     # remove from the nav entirely
menu label: "My Posts"
menu label: proc{ I18n.t "mypost" }            # dynamic label
menu priority: 1                               # default priority 10; sorted by priority, then alpha
menu if: proc{ current_user.can_edit_posts? }  # conditional visibility
menu parent: "Blog"                            # group under a dropdown
menu parent: ["Admin", "Blog"]                 # nested submenu
```

Parent menu items themselves are built at the namespace level (initializer or
`config.namespace do |admin| admin.build_menu do |menu| ... end end`) —
see [setup-and-config.md](setup-and-config.md#utility-navigation-top-right-nav-eg-logout-link) for the mechanism; example of a fully custom/external item:

```ruby
admin.build_menu do |menu|
  menu.add label: "The Application", url: "/", priority: 0
  menu.add label: "Sites" do |sites|
    sites.add label: "Google", url: "https://google.com", html_options: { target: "_blank" }
    sites.add label: "Facebook", url: "https://facebook.com"
  end
end
```

Dynamic parent referenced by id:

```ruby
admin.build_menu do |menu|
  menu.add id: 'blog', label: proc{ "Something dynamic" }, priority: 0
end
menu parent: 'blog'   # in app/admin/post.rb
```

## `scope_to` — restrict the resource's records

```ruby
scope_to :current_user
scope_to :current_user, association_method: :blog_posts
scope_to do
  User.most_popular_posts
end
scope_to :current_user, if:     proc{ current_user.limited_access? }
scope_to :current_user, unless: proc{ current_user.admin? }
```

## `includes` — eager loading

```ruby
includes :author, :categories
```

## `belongs_to` — nested resources

```ruby
ActiveAdmin.register Project
ActiveAdmin.register Ticket do
  belongs_to :project              # → /admin/projects/1/tickets
end

belongs_to :project, optional: true   # reachable with or without a parent in the URL
```

Link to nested resources from the parent's show page:

```ruby
ActiveAdmin.register Project do
  sidebar "Project Details", only: [:show, :edit] do
    ul do
      li link_to "Tickets",    admin_project_tickets_path(resource)
      li link_to "Milestones", admin_project_milestones_path(resource)
    end
  end
end
```

Keep the parent's nav item highlighted while viewing a child resource:

```ruby
ActiveAdmin.register Ticket do
  belongs_to :project
  navigation_menu :project
end

navigation_menu do   # dynamic form
  authorized?(:manage, SomeResource) ? :project : :restricted_menu
end
```

## Customizing resource lookup (`controller do ... end`)

```ruby
controller do
  def scoped_collection
    end_of_association_chain.where(visibility: true)
  end

  def find_resource
    scoped_collection.where(id: params[:id]).first!
  end
end
```

**Route every override of `find_resource` through `scoped_collection`.** Querying the model class
directly bypasses whatever an authorization adapter scopes `scoped_collection` to — see
[gotchas.md](gotchas.md#authorization).

The same `controller do ... end` block is where you add arbitrary instance methods, override
`create`/`update`, add helpers, or override `csv_filename` — see
[actions-and-batch-actions.md](actions-and-batch-actions.md#controller-do--end) for the general
pattern.
