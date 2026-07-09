# Forms

Built on **Formtastic**. Default form (no block) renders every model column:

```ruby
form do |f|
  f.semantic_errors
  f.inputs
  f.actions
end
```

## Anatomy

```ruby
ActiveAdmin.register Post do
  form title: 'A custom title' do |f|
    inputs 'Details' do
      input :title
      input :published_at, label: "Publish Post At"
      li "Created at #{f.object.created_at}" unless f.object.new_record?
      input :category
    end
    panel 'Markup' do
      "The following can be used in the content below..."
    end
    inputs 'Content', :body
    para "Press cancel to return to the list without saving."
    actions
  end
end
```

- `form title: '...'` sets a custom form title.
- Inside the block, `input`/`inputs`/`actions` work with or without the `f.` receiver.
- `f.object` is the underlying model instance (`f.object.new_record?` to branch on new-vs-edit).
- Arbre helpers (`li`, `para`, `panel`) can be interleaved with inputs.

## `f.inputs` — grouping

```ruby
f.inputs 'Details' do              # fieldset with a legend
  f.input :title
  f.input :published_at, label: 'Publish Post At'
end

f.inputs 'Content', :body          # shorthand: title + column list, no block
f.inputs                           # no args → every model column (the default form)
```

## `f.input` — a single field

```ruby
f.input :title
f.input :published_at, label: "Publish Post At"
```

Common options: `label:` (string or proc), `as:` (Formtastic input type — `:string`, `:text`,
`:select`, `:check_boxes`, `:radio`, `:boolean`, `:file`, `:datepicker`, …), `collection:`,
`input_html:`.

### Datepicker

```ruby
f.input :starts_at, as: :datepicker,
                    datepicker_options: { min_date: "2013-10-8", max_date: "+3D" }

f.input :ends_at, as: :datepicker,
                  datepicker_options: { min_date: 3.days.ago.to_date, max_date: "+1W +5D" }
```

`datepicker_options` accepts absolute date strings, `Date` objects, or relative offsets
(`"+3D"`, `"+1W +5D"`).

## `f.semantic_errors`

```ruby
f.semantic_errors                                    # shows errors on :base only, by default
f.semantic_errors *f.object.errors.attribute_names    # show every attribute's errors
```

## `f.actions`

Renders Submit/Cancel. Call as `f.actions` or bare `actions`.

## Nested forms — `f.has_many`

```ruby
ActiveAdmin.register Post do
  permit_params :title, :published_at, :body,
    categories_attributes: [:id, :title, :_destroy],
    taggings_attributes:   [:id, :tag],
    comment_attributes:    [:id, :body, :_destroy]

  form do |f|
    f.inputs 'Details' do
      f.input :title
      f.input :published_at, label: 'Publish Post At'
    end
    f.inputs 'Content', :body

    f.inputs 'Themes' do
      f.has_many :categories, heading: false, allow_destroy: true, new_record: false do |a|
        a.input :title
      end
    end

    f.inputs 'Tags' do
      f.has_many :taggings, heading: false, sortable: :position, sortable_start: 1 do |t|
        t.input :tag
      end
    end

    f.inputs 'Comments' do
      f.has_many :comments,
                 heading: false,
                 new_record: 'Leave Comment',
                 remove_record: 'Remove Comment',
                 allow_destroy: -> (c) { c.author?(current_admin_user) } do |b|
        b.input :body
      end
    end

    f.actions
  end
end
```

`f.has_many :association, <options> do |sub_form| ... end`:

| Option | Meaning |
| --- | --- |
| `allow_destroy:` | Adds a removal checkbox. Boolean, a method name (called on the child), or a `Proc` receiving the child record. |
| `heading:` | Custom heading text, or `false` to hide it. |
| `new_record:` | `false` hides the "add new" button; a string relabels it. |
| `remove_record:` | Relabels the remove button. |
| `sortable:` | Column used for drag-and-drop ordering. |
| `sortable_start:` | Starting position value (default `0`). |

**Nested attributes must be whitelisted via `permit_params` as `<association>_attributes: [...]`,
including `:id` and `:_destroy`** when editing/removing existing records — see
[gotchas.md](gotchas.md#strong-parameters).

## Rendering a form partial

```ruby
ActiveAdmin.register Post do
  form partial: 'form'
end
```

```erb
= semantic_form_for [:admin, @post], builder: ActiveAdmin::FormBuilder do |f|
  = f.inputs "Details" do
    = f.input :title
  - f.has_many :taggings, sortable: :position, sortable_start: 1 do |t|
    - t.input :tag
  = f.actions
```

## "Create Another" checkbox

```ruby
ActiveAdmin.setup do |config|
  config.create_another = true   # application-wide
end

ActiveAdmin.register Post do
  config.create_another = true   # per-resource
end
```
