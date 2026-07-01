# Stack Adapter: Cross-Stack (Rails ↔ React)

For polyglot apps where a Rails backend serves a React frontend (typical of
the `crm-web` codebase). Loaded *in addition to* `rails.md` and `react-ts.md`
when both are present.

## The cross-stack contract surface

Every place where a Rails-shaped value crosses to a JS-shaped consumer is a
contract. Each one is a place future change can silently break the other
side.

### Rails → React shapes

| Producer | Consumer | Contract |
|----------|----------|----------|
| `app/serializers/*.rb` | TS types in frontend | JSON shape |
| `app/views/*.json.jbuilder` | TS types | JSON shape |
| `routes.rb` | `app/assets/javascripts/env/routes.js.erb` | URL helpers |
| Rails enums | TS string-literal unions | Enum values |
| `ActionCable` channels | JS subscribers | Event payloads |
| Job arg shapes | Job-triggering JS | (rare) |
| Webhook payloads | JS handlers | Payload shape |

### React → Rails shapes

| Producer | Consumer | Contract |
|----------|----------|----------|
| Form submit body | Strong-params permit list | Param shape |
| Fetch / XHR body | Controller `params` | Param shape |
| ActionCable client `perform` | Channel actions | Action signature |

## Where drift hides

### Serializer ↔ TS type drift
A Rails serializer adds a field; the TS type doesn't know. Or vice versa:
the TS type expects a field the serializer doesn't produce. Look for:

```bash
# Serializers
ls app/serializers/

# Frontend types likely mirroring them
find app/javascript -name '*.types.ts' -o -name 'types.ts'

# Compare field names (manual diff or codegen tool)
grep -E 'attribute|attributes|fields' app/serializers/user_serializer.rb
grep -E 'name|email|...' app/javascript/types/user.ts
```

If there's no codegen/sync mechanism (graphql-codegen, openapi-typescript,
Sorbet → TS, custom script), assume drift exists and call it out.

### Route helper drift
`routes.js.erb` is rendered server-side — frontend code calls
`Wealthbox.routes.workspace_path(id)`. If a Rails route is renamed and
`routes.js.erb` isn't regenerated/redeployed, the frontend calls a stale
URL. Look for:
- `routes.js.erb` exposing only a *subset* of Rails routes (means manual
  curation = drift risk)
- Frontend code calling routes by string (`/workspaces/${id}`) instead of
  via the helper (means rename = silent breakage)

### Enum drift
Rails:
```ruby
enum status: { draft: 0, published: 1, archived: 2 }
```

Frontend:
```ts
type Status = 'draft' | 'published' | 'archived'
```

When Rails adds `:scheduled`, the frontend type becomes a lie. If shared
enums aren't generated, this is a CoV finding (connascence of value across
services).

### ActionCable / WebSocket payload drift
Server-side `transmit({ ... })` shapes are consumed by JS subscribers. No
type discipline by default. Each channel is a contract.

## Bridge layers

### `react2angular`
The `crm-web` codebase uses `react2angular` to bridge legacy Angular →
React. This is *itself* an extensibility seam:
- New code goes into React.
- Angular code is wrapped, not modified.
- The bridge has a defined boundary (the `react2angular` call site).

Findings on this bridge:
- Angular controllers being modified (per CLAUDE.md, this is forbidden)
- Logic *moved into* React from Angular (per CLAUDE.md, also forbidden)
- The bridge passing complex shapes that suggest logic lives on the wrong
  side
- Bridges that have been there >12 months without progress on retirement

This is a healthy use of the **Strangler Fig** pattern (Fowler) — name it
when reporting.

### Mobile / WebView bridges
If present (`react-native-webview`, custom postMessage bridges): each
message type is a wire-format contract. Changing a message shape silently
breaks the other side.

## Cross-stack vertical slicing

Treat each end-to-end feature as **one vertical slice spanning both stacks**:

```
features/notifications/
  rails:
    app/models/notifications/
    app/services/notifications/
    app/controllers/notifications/
    app/serializers/notifications/
  frontend:
    app/javascript/notifications/
```

The slice is healthy when:
- One git PR can fully implement a notifications change without touching
  files outside `notifications/`-namespaced paths.
- The serializer is the *only* contract surface — frontend doesn't reach
  into other Rails internals.
- Frontend types live next to the feature, not in a global `types/` bin.

The slice is broken when:
- Adding a notification field requires editing the serializer, three
  unrelated controllers, two view templates, and four React components.
- Frontend has its own parallel shape (`{ notif_id, body, ... }`) that
  doesn't match the wire shape.

## Tools / signals to probe for

```bash
# Codegen or schema sources of truth
ls schema.graphql graphql_schema.json openapi*.yml openapi*.json 2>/dev/null

# Sorbet → TS bridges
grep -rn 'sorbet\|sig {' app/ 2>/dev/null

# Frontend → Rails sync
grep -rE 'graphql-codegen|openapi-typescript|swagger-typescript-api' package.json

# `routes.js.erb` health
test -f app/assets/javascripts/env/routes.js.erb && wc -l app/assets/javascripts/env/routes.js.erb
```

## Connascence forms specific to cross-stack

- **CoV across-services**: enum values that must agree across Rails and TS.
- **CoT across-services**: types that must match (serializer output ↔ TS
  type).
- **CoN across-services**: param names — Rails strong params and frontend
  body keys must agree by name.

All three default to `locality = across-services (8)` unless there's an
automated sync mechanism, which collapses locality back toward 1.
