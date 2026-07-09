# Show Pages & Sidebars

## Show Pages

The `show` block renders within the view context using **Arbre** syntax (see
[arbre-decorators-authorization.md](arbre-decorators-authorization.md#arbre-components)).

```ruby
ActiveAdmin.register Post do
  show do
    h3 post.title
    div do
      simple_format post.body
    end
  end
end
```

The resource is available both by its model name (`post`) and as `resource`.

```ruby
show title: :name do   # :name → calls resource.name; or pass a literal string
  # ...
end
```

Rendering a partial: `render 'some_partial', { post: post }` → renders
`app/views/admin/posts/_some_partial.html.erb`.

### `attributes_table_for` — keep AA's styled table inside a custom block

```ruby
ActiveAdmin.register Ad do
  show do
    attributes_table_for(resource) do
      row :title
      row :image do |ad|
        image_tag ad.image.url
      end
    end
    active_admin_comments_for(resource)
  end
end
```

- `row :attr` — a labeled row for an attribute.
- `row :label do |resource| ... end` / `row('Label') { |obj| ... }` — custom row content.
- `attributes_table_for(object)` works on **any** object, not just the current resource — handy
  for rendering an associated record's attributes inside the same show page.

### Panels and nested tables

```ruby
ActiveAdmin.register Book do
  show do
    panel "Table of Contents" do
      table_for book.chapters do
        column :number
        column :title
        column :page
      end
    end
    active_admin_comments_for(resource)
  end

  sidebar :details, only: :show do
    attributes_table_for book do
      row :title
      row :author
      row :publisher
      row('Published?') { |b| status_tag b.published? }
    end
  end
end
```

- `panel "Title" do ... end` — a titled content box.
- `table_for collection do column :attr ... end` — a table for an associated collection.
- `status_tag value` — a styled status badge (booleans render as Yes/No).

### Extending, rather than replacing, the default content

```ruby
show do
  default_main_content   # renders AA's auto-generated attributes table
  h3 "Other Details"
  # ...
end
```

### Comments

The default show page renders comments automatically. If you override `show`, add
`active_admin_comments_for(resource)` yourself to keep them.

## Sidebars

```ruby
sidebar :help do
  para "Need help? Email us at help@example.com"
end
```

The first argument (title) can be a symbol, string, or lambda. Content is Arbre:

```ruby
sidebar :help do
  ul do
    li "Second List First Item"
    li "Second List Second Item"
  end
end
```

### Restricting to specific pages

```ruby
sidebar :help, only: :index do
  # ...
end
```

`only:`/`except:` take a single action or an array (`only: [:show, :edit]`).

### Conditional display

```ruby
sidebar :help, if: proc{ current_admin_user.super_admin? } do
  span "Only for super admins!"
end
```

The proc is evaluated in view context.

### Accessing the record

```ruby
sidebar :custom, only: :show do
  resource.a_method
end
```

### Rendering a partial

```ruby
sidebar :help                     # → app/views/admin/posts/_help_sidebar.html.erb
sidebar :help, partial: 'custom'  # → app/views/admin/posts/_custom.html.erb
```

With no block and no `partial:`, AA looks for `_<title>_sidebar` by convention.

### Styling & ordering

```ruby
sidebar :help, class: 'custom_class'
sidebar :help, priority: 0   # default priority is 10; lower sorts earlier/higher on the page
```

Built-in sidebars (filters, comments) use the default priority — give a custom sidebar a lower
number to place it above them.
