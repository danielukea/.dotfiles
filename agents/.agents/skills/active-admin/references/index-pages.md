# Index Pages

Four built-in renderers — **table** (default, one row per resource), **grid** (cells), **block**
(non-tabular rows), **blog** (title + body). All support filters, scopes, pagination, action
items, and sidebars.

## Choosing / combining renderers

```ruby
index do                              # table (default)
  id_column
  column :image_title
  actions
end

index as: :grid do |product|          # grid
  link_to image_tag(product.image_path), admin_product_path(product)
end

index as: :grid, default: true do |product|   # make a non-default renderer the default
  # ...
end

index as: ActiveAdmin::Views::IndexAsMyIdea do   # a custom renderer class — see below
  column :image_title
  actions
end
```

## Index as Table — columns

```ruby
index do
  selectable_column                        # checkbox column, required for batch actions
  id_column                                # id, linked to the resource
  column :title
  column "My Custom Title", :title         # custom header text
  column "Title" do |post|                 # block form; yields the row's record
    link_to post.title, admin_post_path(post)
  end
  column :secret_data if can? :manage, Post   # conditional column
end
```

Association columns auto-display by trying, in order: `:display_name, :full_name, :name,
:username, :login, :title, :email, :to_s`.

### Actions column

```ruby
index do
  column :title
  actions                                  # default show/edit/delete links

  actions do |post|                        # append a link to the defaults
    item "Preview", admin_preview_post_path(post), class: "preview-link"
  end

  actions defaults: false do |post|        # replace the defaults entirely
    item "View", admin_post_path(post)
  end
end
```

### Sorting

```ruby
column :title, sortable: :title do |post|
  link_to post.title, admin_post_path(post)
end
column :title, sortable: false
column :keywords, sortable: "meta->'keywords'"     # e.g. Postgres hstore
column :publisher, sortable: 'publishers.name'     # sort by an association's column
```

Custom sort SQL (e.g. NULLS ordering):

```ruby
order_by(:title) do |order_clause|
  if order_clause.order == 'desc'
    [order_clause.to_sql, 'NULLS LAST'].join(' ')
  else
    [order_clause.to_sql, 'NULLS FIRST'].join(' ')
  end
end
```

Sorting on an association needs eager loading to avoid N+1 — either `includes :publisher` at the
register-block level, or:

```ruby
controller do
  def scoped_collection
    super.includes :publisher
  end
end
```

### Custom HTML attributes

```ruby
index tbody_html: { class: "my-class", data: { controller: 'stimulus-controller' } } do
  # columns
end

index row_html: ->elem { { class: ('active' if elem.active?), data: { 'element-id' => elem.id } } } do
  # columns
end
```

## Filters

```ruby
filter :title                                   # type inferred from the column
filter :author, as: :check_boxes
filter :author, as: :check_boxes, collection: proc { Author.all }
filter :author, label: 'Something else'
filter :title, filters: [:start, :end]          # restrict which predicate dropdowns appear
filter :name_eq                                 # exact Ransack predicate
filter :name_cont
filter :first_name_or_last_name_cont, as: :string, label: "Name"
```

Types (`as:`): `:string` (Contains/Equals/Starts with/Ends with), `:numeric` (Equal To/Greater
Than/Less Than), `:date_range`, `:select`, `:check_boxes`.

```ruby
preserve_default_filters!    # keep the auto-generated set...
filter :author               # ...and add one

preserve_default_filters!
remove_filter :id            # ...or remove one
```

Disabling filters — per-resource (`config.filters = false` inside `register`), per-namespace, or
globally — see [setup-and-config.md](setup-and-config.md#filters).

**Ransack denies filtering by default** unless the attribute is on that model's
`ransackable_attributes` allowlist — see [gotchas.md](gotchas.md#authorization).

## Scopes

```ruby
scope :all, default: true
scope :active
scope "Subcategories", :leaves                              # custom label + method name
scope ->{ Date.today.strftime '%A' }, :published_today       # dynamic label
scope("Inactive") { |scope| scope.where(active: false) }     # inline block body
scope "Published", if: -> { current_admin_user.can? :manage, Posts } do |posts|
  posts.published
end
```

Mutually-exclusive scope groups:

```ruby
scope :all
scope :active,   group: :status
scope :inactive, group: :status
scope :today,    group: :date
scope :tomorrow, group: :date
```

Scope labels translate via `active_admin.scopes.scope_method`.

## Pagination

```ruby
config.per_page = 10                # per-resource
config.per_page = [10, 50, 100]      # user-selectable options
config.paginate = false              # disable entirely

controller do
  before_action(only: :index) { @per_page = 100 }   # per-request override
end

index pagination_total: false do    # skip the COUNT query
  # ...
end
```

Global default (`config.default_per_page`) lives in the initializer — see
[setup-and-config.md](setup-and-config.md#pagination).

## Download links

```ruby
index download_links: false
index download_links: [:pdf]
index download_links: proc{ current_user.can_view_download_links? }
```

Global equivalents (`config.download_links`) in the initializer. `:pdf` only adds the UI link —
you still implement PDF rendering yourself.

## Custom index component

If table/grid/block/blog don't fit, define your own renderer class (subclass
`ActiveAdmin::Component`, implement `build` + `self.index_name`):

```ruby
module ActiveAdmin
  module Views
    class IndexAsMyIdea < ActiveAdmin::Component
      def build(page_presenter, collection)
        # rendering logic
      end

      def self.index_name
        "my_idea"
      end
    end
  end
end
```

`self.index_name` is required if you want the multiple-index-pages feature (switching between
renderers) to work with this component. Reference it as
`index as: ActiveAdmin::Views::IndexAsMyIdea do ... end`.

## CSV Format

```ruby
csv do
  column :title
  column(:author) { |post| post.author.full_name }   # block yields the record
  column('body', humanize_name: false)                # keep given casing instead of humanizing
end
```

Options forwarded to Ruby's CSV library:

```ruby
csv force_quotes: true, col_sep: ';', column_names: false do
  column :title
end
```

Custom filename:

```ruby
controller do
  def csv_filename
    'User Details.csv'
  end
end
```

CSV streams by default (prevents timeouts on large exports, but hides exceptions in dev — see
[gotchas.md](gotchas.md#csv-export)); global `config.csv_options` / `config.disable_streaming_in`
are in [setup-and-config.md](setup-and-config.md#csv-options). Formula-injection risk on untrusted
data is also in [gotchas.md](gotchas.md#csv-export).
