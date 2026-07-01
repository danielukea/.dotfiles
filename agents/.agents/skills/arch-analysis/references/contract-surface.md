# Contract Surface Lens

You are mapping the *contracts* this code exposes — the shapes, signatures,
and protocols that other code (yours or others') depends on — and finding
where those contracts are implicit, undocumented, or unversioned. Every
implicit contract is a place a future change can silently break a consumer.

## Categories of contract

### External contracts (cross-process)
- HTTP routes and request/response JSON shapes
- WebSocket / SSE event payloads
- gRPC / GraphQL schemas
- Background-job arg shapes (any process picking up the queue is a consumer)
- ENV var consumers (deploy infra is the consumer)
- Webhook payloads sent to or received from third parties
- File / S3 layouts (anything reading the bucket is a consumer)
- DB views, stored procs, triggers visible to other apps
- Public CLI surface (flags, exit codes, output formats)

### Internal cross-slice contracts (inside the codebase)
- Public class/module API of a slice (its `index.ts` / Engine / namespace)
- Method signatures of widely-used utilities
- Shape of records returned by query objects / serializers
- Error class hierarchy
- Pub/sub event payloads (`ActiveSupport::Notifications`, `EventBus.publish`)
- Configuration schemas

### Cross-stack contracts (Rails ↔ React, Mobile ↔ API)
- Serializer output ↔ frontend type definitions
- Route helpers exposed to JS (`routes.js.erb` and similar)
- Shared enums / consts duplicated on both sides
- Bridge layers (`react2angular`, `react-native-webview` postMessages)

## What makes a contract risky

| Property | Healthy | Risky |
|----------|---------|-------|
| **Documented** | Has a schema, type, or spec file | Implicit; "go read the serializer" |
| **Validated** | Schema-checked at the boundary | Trust-the-shape |
| **Versioned** | `/v2/`, header negotiation, deprecation period | One forever-stable shape |
| **Owned** | A slice owns it; one place to change | Shape grew organically across many files |
| **Tested at the boundary** | Contract test or consumer-driven test | Only unit tests of producers |
| **Compatible** | Additive changes only, or with a migration plan | Breaking changes ship without notice |

## How to investigate

### Map external contracts

**Rails routes:**
```bash
bin/rails routes 2>/dev/null | wc -l
bin/rails routes | grep -E '^\s+(GET|POST|PATCH|PUT|DELETE)' | head -30
ls app/serializers app/views/api 2>/dev/null
```

**Job arg shapes:**
```bash
grep -rn 'def perform' app/jobs/ | head
```

**Webhooks / external integrations:**
```bash
grep -rn 'webhook\|sign_secret\|verify_signature' app/ lib/
```

**ENV consumers:**
```bash
grep -rnE 'ENV\[|ENV\.fetch' app/ lib/ config/ | awk -F'[\\[\\(]' '{print $2}' |
  awk -F'[,\\]\\)]' '{print $1}' | sort -u
```

**OpenAPI / JSON Schema presence:**
```bash
find . -name 'openapi*.yml' -o -name 'openapi*.json' -o -name '*.schema.json' 2>/dev/null | head
```

### Map cross-stack contracts (Rails ↔ React)

```bash
# Serializers feeding the frontend
ls app/serializers/

# Route helpers exposed to JS
ls app/assets/javascripts/env/ 2>/dev/null
cat app/assets/javascripts/env/routes.js.erb 2>/dev/null | head -50

# Frontend types that mirror Rails shapes
find app/javascript -name '*.types.ts' -o -name 'types.ts' | head
```

For each serializer, find:
- The matching frontend type (or its absence — finding!)
- Whether the serializer's output is schema-validated anywhere

### Detect versioning

```bash
# Versioned route paths
bin/rails routes 2>/dev/null | grep -E '/v[0-9]'

# Versioned namespaces in code
grep -rn 'module V[0-9]\|namespace :v[0-9]' app/ config/

# Deprecation markers
grep -rn '@deprecated\|deprecate\|DEPRECATION' app/ lib/ src/
```

A codebase with no versioning markers and no deprecation infrastructure is
shipping breaking changes whether it knows it or not.

### Detect implicit consumers

Pub/sub and `ActiveSupport::Notifications` create invisible consumers — the
producer doesn't know who's listening, so changing payload shape silently
breaks subscribers.

```bash
grep -rn 'ActiveSupport::Notifications\.\(instrument\|subscribe\)' app/ lib/
grep -rn 'EventBus\|pubsub\|emit' app/ src/
```

For each event name found, check: who subscribes? Is the payload shape
documented anywhere?

## Output format

Follow the standard agent output schema in SKILL.md (≤ 800 words). Include:

- **Contract inventory**: a table — contract type (route, serializer, job,
  event, ENV, etc.), owner slice, documented? validated? versioned?
- **Risky contracts**: each as a Finding using the exact schema (Connascence
  formula tag — typically CoT, CoP, or CoV).
- **Cross-stack drift candidates**: serializers whose output doesn't match
  any frontend type, or where the frontend type has fields the serializer
  doesn't produce.
- **Implicit consumers**: pub/sub events where subscribers aren't traceable
  from the producer.

## Stack guidance

Load `references/stacks/{detected_stack}.md` and (for polyglot apps)
`references/stacks/cross-stack.md`. Cite at least one applied pattern in
your `### Adapter patterns applied` section.
