# ActiveAdmin templates — using them

The three `templates/active-admin-*.html` files are real ActiveAdmin 3.x default markup and
CSS (verified against the gem's own Arbre view source and stylesheet partials), not an
invented approximation. Ground per-project before treating the output as a finished mockup:

- **Batch actions / comments are per-namespace toggles** (`config.batch_actions`,
  `config.comments` in `active_admin.rb`, or per-resource `config.batch_actions = false`).
  If the target project disables them, delete the block marked `<!-- BATCH ACTIONS -->` in
  `active-admin-index.html` (the checkbox column + selection-toggle panel) — don't leave dead
  chrome in the mockup.
- **Custom status values need their own class.** The default `.status_tag` (no `.yes`/`.no`)
  renders as a pale gray pill — real apps almost always add project-specific status classes
  (e.g. `.status_tag.pending`, `.status_tag.active`) in their own `admin_custom.scss`. If the
  target project's real palette is known, swap those colors in instead of the generic default.
- **Palette is the stock AA 3.x default theme**, not a specific project's branding — safe to
  reuse across projects. Swap tokens only if the target project overrides them systemically
  (check its `active_admin.scss` for SASS variable overrides before `@import` of AA's own
  base — most projects, including crm-web, only override `$link-color`).

## Id/class map (cross-check against a real rendered AA page)

`#wrapper` › `#header` (site title + `ul.tabs` nav) + `#title_bar` (`#titlebar_left` breadcrumb
+ `h2#page_title`, `#titlebar_right` `.action_items`) + `#active_admin_content` ›
`#main_content_wrapper` › `#main_content` + `#sidebar`.

- Index: `.scopes`, `table.index_table` (`tr.even`/`tr.odd`, `.status_tag`, `a.member_link`),
  `.pagination`, `.pagination_information`.
- Show: `.panel` (`h3` + `.panel_contents`), `.attributes_table` (`th`/`td` rows),
  `.sidebar_section`.
- Form: `fieldset.inputs > ol > li.string|select|text|boolean`, `fieldset.actions`,
  `input[type=submit]`.

Source consulted: `activeadmin` gem `lib/active_admin/views/**` (DOM) and
`app/assets/stylesheets/active_admin/**` (CSS) — vendored in crm-web at
`vendor/bundle/ruby/3.2.0/gems/activeadmin-3.2.2/`.
