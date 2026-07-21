---
name: active-admin
description: Deep DSL reference for the ActiveAdmin Ruby gem (activeadmin.info) — resources, index/show/form pages, filters, scopes, batch/member/collection actions, sidebars, decorators, and authorization adapters (CanCanCan/Pundit/custom). Use for any `ActiveAdmin.register` block, `app/admin/*.rb` file, admin index/show/form/filter/sidebar, or authorization adapter. Trigger on "ActiveAdmin", "admin panel gem", "Formtastic", "Arbre", or "Ransack filter". Targets ActiveAdmin 3.x.
---

# ActiveAdmin DSL

Deep reference for the [ActiveAdmin](https://activeadmin.info/) gem's registration DSL. **This
file is a router** — it states the mental model, catalogs what each DSL surface does with a
one-line "when", and gives you gotcha hooks. Full syntax and code live in `references/`; open the
linked file when you're at that decision point.

**Version:** targets ActiveAdmin **3.x** (the stable line; `crm-web` runs `activeadmin 3.5.0`).
4.0 is beta and expected to change the asset pipeline, not the resource DSL below — see
[references/setup-and-config.md](references/setup-and-config.md#version-note) before assuming
parity on a 4.0 app.

## The Core Mental Model

ActiveAdmin is a Rails Engine that generates an admin panel from a small DSL, per model:

```ruby
ActiveAdmin.register Post do
  permit_params :title, :body

  index do        # table/grid/block/blog rendering of the collection
  end
  filter :title   # Ransack-backed filter sidebar
  show do          # Arbre-rendered detail view
  end
  form do |f|      # Formtastic-backed create/edit form
  end
end
```

Four libraries do the real work under the DSL: **Formtastic** (forms), **Arbre** (the Ruby→HTML
templating used in `index`/`show`/custom pages), **Ransack** (filters), and whatever
**authorization adapter** you plug in (CanCanCan, Pundit, or a hand-rolled one). Knowing which
library owns a given surface tells you where to look when something behaves unexpectedly — a
filter silently doing nothing is a Ransack allowlist problem, not an ActiveAdmin bug (see Gotchas).

## Reach for this skill when

- Writing or reviewing an `app/admin/*.rb` resource file
- Customizing index columns/filters/scopes, a show page, or a form
- Adding a `member_action`, `collection_action`, `batch_action`, or a whole custom (non-resource) page
- Wiring up or debugging authorization (CanCanCan/Pundit/custom adapter) for the admin panel
- A filter, batch action, or decorated attribute "isn't working" and you need to know which layer owns it

## DSL Surface → Reference

| Need | Reach for | Reference |
| --- | --- | --- |
| Install / initializer config / auth wiring | `rails g active_admin:install`, `config/initializers/active_admin.rb` | [setup-and-config.md](references/setup-and-config.md) |
| Register a model, whitelist params, scope/eager-load, nest under a parent | `ActiveAdmin.register`, `permit_params`, `scope_to`, `includes`, `belongs_to`, `menu` | [registering-resources.md](references/registering-resources.md) |
| Customize the list view, add filters/scopes, CSV export | `index do end`, `filter`, `scope`, `csv do end` | [index-pages.md](references/index-pages.md) |
| Customize the create/edit form, nested has-many forms | `form do |f| end`, `f.input`, `f.has_many` | [forms.md](references/forms.md) |
| Customize the detail view, add a sidebar panel | `show do end`, `attributes_table_for`, `sidebar` | [show-pages-and-sidebars.md](references/show-pages-and-sidebars.md) |
| Add a one-off controller action, a bulk operation, or a standalone page | `member_action`, `collection_action`, `batch_action`, `ActiveAdmin.register_page` | [actions-and-batch-actions.md](references/actions-and-batch-actions.md) |
| Custom Arbre markup, view-only computed attributes, per-record/per-page permissions | Arbre `panel`/`table_for`/`tabs`, `decorate_with`, `ActiveAdmin::AuthorizationAdapter` | [arbre-decorators-authorization.md](references/arbre-decorators-authorization.md) |
| "This silently doesn't work" | — | [gotchas.md](references/gotchas.md) |

## Gotchas (hooks — full detail in [references/gotchas.md](references/gotchas.md))

| Symptom | Real cause |
| --- | --- |
| A filter does nothing | Ransack denies filtering by default — attribute isn't on `ransackable_attributes` |
| `find_resource` override lets users see others' records | It bypassed `scoped_collection`, so the authorization adapter's scoping never ran |
| Multi-select / HABTM field silently drops on save | `permit_params` needs `attr_ids: []`, not bare `:attr_ids` |
| Edited/removed nested child doesn't persist/delete | `permit_params` needs `:id` and `:_destroy` in the `_attributes` array |
| Custom decorator's edit/show/destroy links 404 | Decorator doesn't delegate `to_param` |
| Form doesn't reflect decorator methods | Forms aren't decorated by default — needs `form decorate: true` |
| Batch `:destroy` fails silently under Pundit | Policy class is missing `destroy_all?` |
| Flash/session stop working after an asset config change | `config.assets.prefix` collides with ActiveAdmin's mount namespace |
| A model's `search` class method breaks | Collides with Ransack's `search` (namespace the other gem's method instead) |
| CSV export looks tampered with in Excel | Untrusted data in a CSV column — formula-injection risk, sanitize leading `=`/`+`/`-`/`@` |
| Auth config seems ignored | An existing `ApplicationController` `before_action` runs before `config.authentication_method` is ever consulted |

## Bundled References

- **[references/setup-and-config.md](references/setup-and-config.md)** — install steps, every verified `config.x =` initializer option (auth, site title, i18n, namespaces, comments, batch actions, CSV, pagination, download links, authorization), version note.
- **[references/registering-resources.md](references/registering-resources.md)** — `ActiveAdmin.register` anatomy: `permit_params`, `actions`, renaming, `menu`, `scope_to`, `includes`, `belongs_to`, `scoped_collection`/`find_resource` overrides.
- **[references/index-pages.md](references/index-pages.md)** — table/grid/block/blog renderers, columns, sorting, filters, scopes, pagination, download links, custom index components, CSV format.
- **[references/forms.md](references/forms.md)** — Formtastic `form`/`input`/`inputs`, `f.has_many` nested forms, partials, "create another".
- **[references/show-pages-and-sidebars.md](references/show-pages-and-sidebars.md)** — `show`, `attributes_table_for`, panels, tabs, `sidebar` (scoping, conditionals, partials, priority).
- **[references/actions-and-batch-actions.md](references/actions-and-batch-actions.md)** — `member_action`/`collection_action`/`action_item`, `controller do end`, `batch_action` (incl. `form:`), `ActiveAdmin.register_page`/`page_action`.
- **[references/arbre-decorators-authorization.md](references/arbre-decorators-authorization.md)** — built-in Arbre components, `decorate_with`, writing/wiring an authorization adapter (custom, CanCanCan, Pundit).
- **[references/gotchas.md](references/gotchas.md)** — every gotcha above, in full, plus CSS/asset and naming-conflict traps not summarized here.

---

*Sources: [activeadmin.info](https://activeadmin.info/) documentation pages 0–14, fetched directly
— not reconstructed from training memory. Verified against `crm-web`'s installed `activeadmin
3.5.0` for version targeting.*
