# Custom Controller Actions, Batch Actions & Custom Pages

## Custom Controller Actions

### `collection_action` — operates on the collection (no `:id`)

```ruby
ActiveAdmin.register Post do
  collection_action :import_csv, method: :post do
    # ... CSV importing work ...
    redirect_to collection_path, notice: "CSV imported successfully!"
  end
end
```

Route: `/admin/posts/import_csv`.

### `member_action` — operates on a single resource

```ruby
ActiveAdmin.register User do
  member_action :lock, method: :put do
    resource.lock!
    redirect_to resource_path, notice: "Locked!"
  end
end
```

Route: `/admin/users/:id/lock`. `resource` inside the block is the loaded record.

### Multiple HTTP verbs

```ruby
member_action :foo, method: [:get, :post] do
  if request.post?
    resource.update! foo: params[:foo] || {}
    head :ok
  else
    render :foo
  end
end
```

### Path helpers inside the block

- `collection_path` — the index/collection path (use in `collection_action` redirects).
- `resource_path` — the current member's show path (use in `member_action` redirects).
- Standard Rails named routes (`post_path(resource)`) also work.

### Rendering a view / setting the page title

```ruby
member_action :comments do
  @comments = resource.comments
  @page_title = "#{resource.title}: Comments"   # overrides the default heading
  # renders app/views/admin/posts/comments.html.erb
end
```

### `action_item` — add a toolbar button/link

```ruby
action_item :view, only: :show do
  link_to 'View on site', post_path(resource) if resource.published?
end

action_item :super_action, only: :show, if: proc{ current_admin_user.super_admin? } do
  "Only display this to super admins on the show screen"
end

action_item :help, priority: 0 do   # default priority is 10; lower = earlier position
  "Display this action to the first position"
end
```

`only:`/`except:` take `:show`, `:index`, `:edit`, `:new` (symbol or array). `if:` is a proc
evaluated in view context.

### `controller do ... end` {#controller-do--end}

Add instance methods to, or override, the underlying (InheritedResources-based) controller:

```ruby
ActiveAdmin.register Post do
  controller do
    def define_a_method
      # instance method, available to views/actions in this resource
    end
  end
end
```

Common uses: override `create`/`update` (reading `permitted_params`, not raw `params` — see
[gotchas.md](gotchas.md#strong-parameters)), override `scoped_collection`/`find_resource` (see
[registering-resources.md](registering-resources.md#customizing-resource-lookup-controller-do--end)),
override `csv_filename`, or add `helper SomeHelper`.

## Batch Actions

### Enabling selection

```ruby
index do
  selectable_column   # required for batch actions to have anything to act on
  # ...
end
```

Fully custom index views use `resource_selection_cell` instead:

```ruby
index as: :custom do |post|
  resource_selection_cell post
  h2 auto_link post
end
```

### Defining one

```ruby
ActiveAdmin.register Post do
  batch_action :flag do |ids|
    batch_action_collection.find(ids).each do |post|
      post.flag! :hot
    end
    redirect_to collection_path, alert: "The posts have been flagged."
  end
end
```

The block receives an array of selected **IDs** (strings). Load records through
`batch_action_collection.find(ids)` — scoped the same way the index collection is scoped.

### Overriding / disabling

```ruby
batch_action :destroy do |ids|          # override the built-in :destroy
  redirect_to collection_path, alert: "Didn't really delete these!"
end

batch_action :destroy, false            # remove a specific batch action

config.batch_actions = false            # disable all, per-resource
```

Global/per-namespace disabling is in [setup-and-config.md](setup-and-config.md#batch-actions).

### Options

```ruby
batch_action :flag, if: proc { can? :flag, Post } do |ids|
  # ...
end

batch_action :destroy, priority: 1 do |ids|   # ordering in the dropdown
  # ...
end

batch_action :destroy, confirm: "Are you sure??" do |ids|
  # ...
end
```

### `form:` — collect input before running

```ruby
batch_action :flag, form: {
  type:  %w[Offensive Spam Other],   # → select dropdown
  reason: :text,
  notes:  :textarea,
  hide:   :checkbox,
  date:   :datepicker
} do |ids, inputs|
  redirect_to collection_path, notice: [ids, inputs].to_s
end
```

The block gains a second argument (`inputs`) — a hash of the submitted form fields. `[label,
value]` pairs give explicit dropdown options:

```ruby
batch_action :doit, form: { user: [['Jake', 2], ['Mary', 3]] } do |ids, inputs|
  User.find(inputs[:user])
end
```

A proc/lambda builds the form dynamically at render time:

```ruby
batch_action :doit, form: -> { { user: User.pluck(:name, :id) } } do |ids, inputs|
  User.find(inputs[:user])
end
```

### Labels

Resolved via I18n key `active_admin.batch_actions.labels.#{action_name}`.

### Gotcha

The whole index view is one `<form>` used to submit selected IDs. See
[gotchas.md](gotchas.md#batch-actions) before nesting another form inside a custom index block.

## Custom Pages

For content **not backed by a resource** — dashboards, settings, calendars.

```ruby
ActiveAdmin.register_page "Calendar" do
  content do
    para "Hello World"
  end
end
```

- `content do ... end` — the page body, in Arbre. Supports `render partial: 'calendar'` the same
  way resources do.
- `breadcrumb do ['admin', 'calendar'] end` — custom breadcrumb trail.
- `namespace:` — `ActiveAdmin.register_page "Calendar", namespace: :today`, or `namespace: false`
  to mount outside any namespace (e.g. at `/calendar`). Default namespace is `admin`.
- `belongs_to :project` — same nesting concept as resources.
- `action_item :view_site do link_to "View Site", "/" end` — toolbar link (`:only`/`:except`
  don't apply; a page has one view).

### `page_action` — a custom action + route scoped to the page

```ruby
page_action :add_event, method: :post do
  redirect_to admin_calendar_path, notice: "Your event was added"
end

action_item :add do
  link_to "Add Event", admin_calendar_add_event_path, method: :post
end
```

Route form: `/admin/calendar/add_event`, named helper `admin_calendar_add_event_path`. Accepts a
single verb or an array (`method: [:get, :post]`), same as `member_action`/`collection_action`.
