# Views, Helpers, and Fragment Caching

## Locals, not instance variables

Instance variables belong to top-level templates. **Every partial takes explicit locals**, even
when the ivar is in scope:

```erb
<%= render "cards/container", card: @card %>
<%= render "cards/messages",  card: @card %>
```

A partial that reads `@card` is coupled to whichever controller happens to set it, so it can't
be reused and can't be reasoned about locally. A partial that takes `card:` states its contract.

Optional locals go through `local_assigns`:

```erb
<% draggable = local_assigns.fetch(:draggable, false) %>
```

## One directory per presentation, not one partial with branches

When the same record renders several ways, give each presentation its own directory and share a
`common/` sibling:

```
app/views/cards/display/
  perma/     _assignees  _meta  _tags
  preview/   _assignees  _meta  _tags
  mini/      _meta
  common/    _assignees  _tags
```

This beats a single partial threading `variant:`/`size:` locals through nested conditionals —
each presentation reads top to bottom, and adding a fourth doesn't touch the other three.

## `to_partial_path` to relocate a model's partials

```ruby
class Comment < ApplicationRecord
  def to_partial_path
    "cards/#{super}"     # => "cards/comments/comment"
  end
end
```

Use it for namespacing under a parent resource, not for renaming.

## `dom_id` is shared vocabulary

```erb
<section id="<%= dom_id(card, :card_container) %>">
```

Reuse the same suffix vocabulary for element ids, anchors, and update targets, so server and
client agree without a comment explaining the scheme. It also works **outside** views — call it
from a model or job rather than interpolating strings:

```ruby
ActionView::RecordIdentifier.dom_id(comment)   # => "comment_123"
```

Never hand-build `"comment_#{id}"`. The moment one place disagrees, the bug is invisible.

## What earns a helper

A helper should encode an element's **contract** — its id, classes, data attributes, and ARIA —
so the wiring cannot drift between call sites:

```ruby
def messages_tag(card, &)
  tag.div id: dom_id(card, :messages),
    class: "comments gap center",
    role: "group", aria: { label: "Messages" }, &
end
```

That earns its place: three call sites can't disagree about the role or the id.

What does **not** earn a helper: formatting a date, pluralizing a word, or wrapping a single
method call. Those belong in the model, a partial, or Rails' existing helpers.

Two more patterns worth knowing:

- **Helpers that append rather than replace.** When wrapping `form_with`, merge the caller's
  attributes instead of clobbering them:

  ```ruby
  classes = [ options[:class], "form" ].compact.join(" ")
  ```

- **Namespace helpers by view directory** — `app/helpers/my/menu_helper.rb` → `My::MenuHelper`
  for `app/views/my/`. A flat `ApplicationHelper` becomes a junk drawer.

Inside nested `tag.x do` blocks you need `concat` to emit multiple children — a silent
truncation otherwise.

## Layout state via ivars; `content_for` for markup

Scalars the layout needs are plain ivars, assigned at the top of the template:

```erb
<% @page_title = @card.title %>
<% @body_class = "card-perma" %>
```

```erb
<body class="<%= @body_class %>">
```

Reserve `content_for` for actual regions of HTML (`:head`, `:footer`). Using it for a string is
indirection for nothing.

Values every view needs (`Current.user`, `Current.account`) are read directly rather than
assigned per-action. Expose a computed one with `helper_method`, sparingly — a handful in a whole
app is the right order of magnitude.

## Fragment caching

`cache` around a record keys on its `updated_at` and the template digest:

```erb
<% cache card do %>
  ...
<% end %>
```

### Keep identity outside the cache block

The element's id, its CSS custom properties, and any per-viewer fragment must live **outside**,
or the first cache hit freezes them for everyone:

```erb
<section id="<%= dom_id(card, :card_container) %>" style="--card-color: <%= card.color %>;">
  <% cache card do %>
    ...
  <% end %>

  <%= render "cards/footer", card: card %>   <%# per-user: not cacheable %>
</section>
```

### Under-keying is the usual bug

`cache record` alone is almost always wrong for anything personalized. Compose an **array** of
every dimension the fragment varies by:

```erb
<% cache [ Current.user, card, Time.zone.name ] do %>
```

Include the viewer if it's personalized, and `Time.zone.name` anywhere times are rendered —
otherwise a user in another zone gets someone else's clock.

A **relation** as the first element works and self-invalidates — Rails derives `count` plus
`max(updated_at)` from it, at the cost of one aggregate query:

```erb
<% cache [ day.events, Time.zone.name ] do %>
```

### Collection caching

```erb
<%= render partial: "cards/preview", collection: cards, cached: true %>
```

This multi-gets the whole collection in one round trip. The constraint agents miss: the
collection partial must be **the only thing rendered**, and each element supplies its own key —
which is why the wrapper partial is often a single line.

### Dynamic partial paths defeat the digestor

Rails' template digest only sees **statically parseable** `render` calls. A computed path is
invisible, so editing the sub-partial never invalidates the parent's cache:

```erb
<% cache event do %>
  <%# Template Dependency Updated: _layout.html.erb 2026-01-26 %>
  <%= render "events/kinds/#{event.action}", event: event %>
<% end %>
```

You now own invalidation manually. Either declare it (`<%# Template Dependency: path %>`) or bump
a dated comment when the sub-partial changes. For an optional polymorphic partial, check first —
note the leading underscore:

```erb
<% if lookup_context.exists?("events/kinds/_#{event.action}") %>
```

### Non-record objects can be cached

A value object participates by implementing `cache_key`, plus an explicit predicate for whether
it's cacheable at all:

```ruby
def cache_key
  ActiveSupport::Cache.expand_cache_key [ user, filter, day, Time.zone.name ], "day-timeline"
end

def cacheable? = filter.boards.exists?
```

Letting the object decide beats the view guessing.

### Caching is off in dev and test — really off

`config.cache_store = :null_store` is what makes "caching disabled" real; toggling
`perform_caching` alone is not enough. Two consequences:

- Cache bugs never surface locally. Enable caching deliberately when changing cache keys.
- **Collection caching needs a second store.** `cached: true` reads
  `ActionView::PartialRenderer.collection_cache`, which `perform_caching` does not cover — swap
  it explicitly in a test that exercises collection caching, or the test proves nothing.

## HTTP caching

`etag {}` is **additive** — several concerns can each contribute, and Rails combines them:

```ruby
class ApplicationController < ActionController::Base
  etag { "v1" }        # bump to invalidate everything
end

module CurrentTimezone
  included { etag { timezone_from_cookie } }
end
```

Per-action freshness goes through `fresh_when`. For an absent state, supply a sentinel — a nil
etag is meaningless:

```ruby
fresh_when etag: @card.pin_for(Current.user) || "none"
```
