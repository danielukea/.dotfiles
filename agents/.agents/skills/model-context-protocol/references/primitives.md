# MCP Architecture and Primitives

## Architecture

**Host / Client / Server.** The **host** is the AI application the user interacts with (Claude Code,
Claude Desktop, an IDE) — it creates and manages client instances, controls their permissions,
enforces consent, and coordinates LLM integration. The **client** is the protocol-level connector
inside the host, one per server connection. The **server** provides context, regardless of where it
runs: **local** servers are spawned as a subprocess over stdio; **remote** servers talk Streamable
HTTP to many clients.

**MCP is a stateless protocol** — every request is self-contained and carries its own protocol
version and capabilities. A client connection is *not* a session or a conversation; see
[request-model-and-transports.md](request-model-and-transports.md#statelessness--the-rule-everything-else-follows-from).
This is the biggest single change from `2025-11-25` and it colors every primitive below.

**Two-layer model.**
- **Data layer** — the JSON-RPC 2.0 protocol: the per-request model plus the primitives below.
- **Transport layer** — stdio or Streamable HTTP; see
  [request-model-and-transports.md](request-model-and-transports.md#transports).

**JSON-RPC 2.0 wire protocol.** Requests carry `jsonrpc:"2.0"`, a non-null `id`, `method`, and
`params`; responses echo the `id` and carry `result` or `error`. Notifications have no `id` and get no
response. Two rules new in `2026-07-28`:

- **Every result MUST carry `resultType`.** `"complete"` for an ordinary result, `"input_required"`
  for an [MRTR](mrtr.md) interim result. Extensions MAY add values (only ones advertised via
  capabilities count); an unrecognized value **MUST** be treated as invalid. **An absent `resultType`
  MUST be read as `"complete"`** — that's the compatibility hook for older servers.
- **Error-code allocation policy.** Standard JSON-RPC codes still apply. Within the
  implementation-defined range: `-32000`–`-32019` is **legacy** (new code MUST NOT allocate here, and
  receivers MUST NOT assume meaning), while `-32020`–`-32099` is **reserved for the spec** —
  `-32020` `HeaderMismatch`, `-32021` `MissingRequiredClientCapability`, `-32022`
  `UnsupportedProtocolVersion`. Retired and never reused: `-32002` (resource not found → now
  `-32602`; clients SHOULD still *accept* it from older servers) and `-32042` (URL elicitation
  required, `2025-11-25` only). New application error codes SHOULD live outside `-32768`–`-32000`.

**The `_meta` convention.** Many object types (tool defs, content blocks, requests/results) accept
`_meta` for out-of-band metadata. Key format: optional reverse-DNS prefix + name; any prefix whose
second label is `modelcontextprotocol` or `mcp` is **reserved** (`io.modelcontextprotocol/`,
`dev.mcp/`, `com.mcp.tools/` — but `com.example.mcp/` is fine). `_meta` now carries far more weight
than it used to: it is where the **protocol version, client capabilities, client/server identity, and
log level live** (see
[request-model-and-transports.md](request-model-and-transports.md#per-request-metadata-_meta)), plus
[extensions](versioning-and-extensions.md#extensions) and — as an explicit exception to the prefix
rule — the W3C Trace Context keys `traceparent`/`tracestate`/`baggage` for OpenTelemetry propagation
(Ruby specifics: `mcp-ruby-sdk`'s server-dsl.md).

**JSON Schema rules.** Default dialect is **2020-12** when `$schema` is absent; implementations MUST
support at least 2020-12 and MUST handle unsupported dialects with a clear error. Two hardening rules
worth knowing: implementations **MUST NOT** auto-dereference a `$ref` resolving to a network URI (an
opt-in fetcher must be off by default, allowlisted, and must reject loopback/link-local/private
addresses), and they **SHOULD** bound composition keywords (`anyOf`/`oneOf`/`allOf`/`if`-`then`-`else`,
`$defs`) by depth, subschema count, or time budget — an unbounded schema is a DoS vector against your
validator.

## Control-model taxonomy

Every primitive has an owner and a controller — the single most important fact for choosing one:

| Primitive | Offered by | Controlled by | Status | Role |
| --- | --- | --- | --- | --- |
| **Tools** | Server | **Model** | Active | Functions the LLM invokes to take actions |
| **Resources** | Server | **Application** | Active | Passive, read-only context data |
| **Prompts** | Server | **User** | Active | Reusable templates, explicitly invoked |
| **Elicitation** | Client | Server-requested, user-gated | Active | Server requests info/confirmation from the user |
| **Sampling** | Client | Server-requested, user-gated | **Deprecated** (SEP-2577) | Server asks the client's LLM for a completion |
| **Roots** | Client | App/User | **Deprecated** (SEP-2577) | Filesystem boundaries (advisory) |
| **Logging** | Client | Server-emitted | **Deprecated** (SEP-2577) | Server sends log messages to the client |

**"Deprecated" here means still fully specified and functional**, with a documented migration path and
removal not eligible until a revision released on or after **2027-07-28** — not "gone." See
[versioning-and-extensions.md](versioning-and-extensions.md#feature-lifecycle-sep-2596).

**All three client features are now delivered via [MRTR](mrtr.md), not server-initiated requests.**

## Tools

Model-controlled: the LLM discovers and invokes tools based on context and the user's prompts. Use for
anything that *does* something — mutates state, calls an API, triggers a side effect.

**Methods:** `tools/list` (paginated), `tools/call`. Notification:
`notifications/tools/list_changed` (delivered on a
[`subscriptions/listen`](request-model-and-transports.md#subscriptionslisten) stream).
**Capability:** `{ "capabilities": { "tools": { "listChanged": true } } }`

**Tool definition fields:** `name` (unique; SHOULD be 1–128 chars, `[A-Za-z0-9_.-]`, case-sensitive,
no spaces — SHOULDs in the spec, though most SDKs enforce them as MUSTs), `title`, `description`,
`inputSchema` (a no-param tool still needs `{"type":"object","additionalProperties":false}`, never
null), optional `outputSchema`, `annotations`, `icons`.

Two `2026-07-28` changes here:
- **`execution.taskSupport` is gone from core** — Tasks is now the
  `io.modelcontextprotocol/tasks` [extension](versioning-and-extensions.md#extensions).
- **Servers SHOULD return `tools/list` in a deterministic order** (same ordering across requests while
  the underlying set is unchanged) so clients can cache the list and so tools included in model
  context hit the LLM's prompt cache.
- `inputSchema`/`outputSchema` now allow **any** JSON Schema 2020-12 keywords, and
  `structuredContent` any JSON value (SEP-2106) — looser than the earlier restricted profile.

**Tool annotations (hints) — and what they're *not* for.** `annotations` on a tool def is a distinct
thing from the content `audience`/`priority`/`lastModified` annotations on Resources/Prompts/tool
content (below) — don't conflate them. Four optional hints, each with a spec default:

| Hint | Default | Meaning |
| --- | --- | --- |
| `readOnlyHint` | `false` | Tool does not modify its environment |
| `destructiveHint` | `true` | May perform destructive updates (meaningful only when `readOnlyHint` is false) |
| `idempotentHint` | `false` | Repeat calls with the same args have no additional effect (meaningful only when `readOnlyHint` is false) |
| `openWorldHint` | `true` | Interacts with an open-ended external world (web search) vs. a closed domain (a memory store) |

These are **hints, not guarantees, and not meant to drive caching or security decisions**: "Clients
should never make tool use decisions based on ToolAnnotations received from untrusted servers." A
malicious server can claim `readOnlyHint: true` and mutate anyway. Their documented purpose is
confirmation-prompt UX and policy/trust decisions — see [caching.md](caching.md) for why they're not a
caching signal.

```json
// tools/call request (_meta abbreviated — every request MUST carry the required fields)
{ "jsonrpc":"2.0","id":2,"method":"tools/call","params":{
  "name":"get_weather","arguments":{"location":"New York"},
  "_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28",
           "io.modelcontextprotocol/clientCapabilities":{}}} }
// result
{ "jsonrpc":"2.0","id":2,"result":{
  "resultType":"complete",
  "content":[{"type":"text","text":"Current weather in New York:\nTemperature: 72°F"}],
  "isError":false } }
```

**Result shape — two kinds of content:**
- **Unstructured** `content` array: `text`, `image` (base64+mimeType), `audio`, `resource_link` (a URI
  pointing at a Resource — **not guaranteed** to appear in `resources/list`), or an embedded full
  `resource`.
- **Structured** `structuredContent`. If the tool declared `outputSchema`, the server MUST conform and
  clients SHOULD validate. For backward compat, also serialize the same JSON into a `text` block.

**Two distinct error mechanisms — don't conflate them:**
- **Protocol errors** — a JSON-RPC `error` (e.g. `-32602` unknown tool). Models rarely recover.
- **Tool execution errors** — a *successful* result with `"isError":true` and actionable text. API,
  validation, and business-logic failures all belong here, so the client can feed them back to the LLM
  for self-correction.

**Trap:** tool descriptions and annotations are **not authenticated data**. Clients "MUST consider tool
annotations to be untrusted unless they come from trusted servers" — a compromised server can embed
prompt-injection payloads in a tool's own description.

A tool's `inputSchema` may also carry **`x-mcp-header`** annotations that mirror parameters into HTTP
headers; the constraints and the client's must-drop-the-tool obligation are in
[request-model-and-transports.md](request-model-and-transports.md#required-headers).

## Resources

Application-controlled. Passive, **read-only** data that the *app* — not the model — decides to
surface (pickers, search, auto-embedding). No mandated UI.

**Methods:** `resources/list` (paginated), `resources/templates/list`, `resources/read`.
Notifications: `notifications/resources/list_changed`, `notifications/resources/updated`.
**Capability:** `{ "capabilities": { "resources": { "subscribe": true, "listChanged": true } } }` —
independent flags; `{ "resources": {} }` means neither.

**`resources/subscribe` and `resources/unsubscribe` no longer exist.** The `subscribe` *capability*
survives, but the mechanism is now a
[`subscriptions/listen`](request-model-and-transports.md#subscriptionslisten) request listing URIs in
`notifications.resourceSubscriptions`; `notifications/resources/updated` then arrives on that stream
tagged with `io.modelcontextprotocol/subscriptionId`.

**Identity:** a unique URI (RFC 3986) + MIME type. Two discovery patterns: **direct** (fixed URI, e.g.
`calendar://events/2024`) and **resource templates** (RFC 6570 URI templates, e.g.
`travel://activities/{city}/{category}`; template args support completion).

```json
{ "jsonrpc":"2.0","id":2,"result":{"resultType":"complete","contents":[{
  "uri":"file:///project/src/main.rs","mimeType":"text/x-rust",
  "text":"fn main() {\n    println!(\"Hello world!\");\n}"}],
  "ttlMs":60000,"cacheScope":"private"} }
```

`resources/read` results **MUST** carry `ttlMs`/`cacheScope` — see [caching.md](caching.md).

**Content** is text (`text`) or binary (`blob`, base64). **Content annotations** (shared with
prompts/tool content — a different thing from the tool *hints* above): `audience`
(`["user","assistant"]`), `priority` (0.0–1.0), `lastModified` (ISO 8601 — **display-only**, e.g. for
sorting by recency; not a cache validator, and MCP still has no ETag/If-Modified-Since equivalent).
**URI schemes:** `https://` (only when the client can fetch it directly, not via the server),
`file://`, `git://`, or custom.

**Errors:** resource not found is now **`-32602`** (was `-32002`); clients **SHOULD** still accept
`-32002` from servers on earlier revisions. Internal errors `-32603`.

`resources/read` **MAY** return an [`InputRequiredResult`](mrtr.md).

## Prompts

User-controlled: exposed so the user can **explicitly select** them — slash commands, command
palettes, buttons. **Never auto-triggered.** Use for a curated, parameterized workflow that shows how
to best combine a server's tools + resources.

**Methods:** `prompts/list` (paginated), `prompts/get`. Notification:
`notifications/prompts/list_changed`.
**Capability:** `{ "capabilities": { "prompts": { "listChanged": true } } }`
**Definition fields:** `name`, `title`, `description`, `icons`, `arguments`
(`{name, description, required}[]`).

```json
{ "jsonrpc":"2.0","id":2,"result":{"resultType":"complete","description":"Code review prompt",
  "messages":[{"role":"user","content":{"type":"text","text":"Please review this Python code:\n..."}}]} }
```

`PromptMessage.role` is `"user"` or `"assistant"`; `content` can be `text`, `image`, `audio`, or an
embedded `resource`. Arguments support completion. Errors: invalid name / missing required args →
`-32602`. `prompts/get` **MAY** return an [`InputRequiredResult`](mrtr.md).

## Client features — all delivered via MRTR

None of these are server-initiated requests anymore. A server asks for them by returning an
`InputRequiredResult` whose `inputRequests` map contains an `ElicitRequest`, `CreateMessageRequest`,
or `ListRootsRequest`; the client answers in `inputResponses` on a retry. Read [mrtr.md](mrtr.md)
before implementing any of the three. Client capabilities are declared **per request**, in
`_meta.io.modelcontextprotocol/clientCapabilities`.

### Elicitation (Active)

The only client feature not deprecated. Two modes:

**Capability:** `{ "elicitation": { "form": {}, "url": {} } }`. An empty object ≡ **form only** (back
compat). A client declaring `elicitation` **MUST** support at least one mode; a server **MUST NOT**
send a mode the client doesn't support. `mode` is optional for form and defaults to `"form"` when
omitted.

- **`form` mode** — in-band, structured. `requestedSchema` is a **restricted** JSON Schema subset:
  flat objects, primitives only (string/number/boolean/enum), formats `email`/`uri`/`date`/`date-time`,
  no nested objects or arrays-of-objects.
  ```json
  { "method":"elicitation/create","params":{
    "mode":"form","message":"Please provide your contact information",
    "requestedSchema":{"type":"object","properties":{
      "name":{"type":"string"},"email":{"type":"string","format":"email"}},
      "required":["name","email"]}} }
  ```
  Response: `{"action":"accept"|"decline"|"cancel", "content": {...}}` (`content` only on `accept`).
  **Trap: form mode MUST NOT request secrets** — passwords, API keys, tokens, payment details require
  `url` mode. (Ordinary personal data like a name or username isn't categorically prohibited; it's a
  server judgment call.)
- **`url` mode** — out-of-band navigation for sensitive interactions (auth, payment); data other than
  the URL is never exposed to the client. `accept` means the user *agreed to open the URL*, not that
  the flow completed. Clients SHOULD display the target host and gather consent before navigating.

**Removed in `2026-07-28`:** `notifications/elicitation/complete`, the `elicitationId` field, and the
`-32042` `URLElicitationRequiredError`. Under MRTR the client learns the outcome by **retrying the
original request**, so a server-initiated completion signal no longer fits. A server needing to
correlate an out-of-band interaction across retries encodes its own identifier in
[`requestState`](mrtr.md).

### Sampling (Deprecated — SEP-2577)

Lets a server get LLM completions through the client, with no model or API key of its own. Migration
path: **integrate directly with an LLM provider API.**

**Capability:** `{ "sampling": {} }`; with tool calling `{ "sampling": { "tools": {} } }`.
**Request params:** `messages`, `modelPreferences` (`hints` — advisory model-name substrings a client
MAY map cross-provider — plus `costPriority`/`speedPriority`/`intelligencePriority` 0–1),
`systemPrompt`, `maxTokens`, optional `tools` + `toolChoice`.

`includeContext: "thisServer"` / `"allServers"` are themselves **Deprecated** — omit the field or use
`"none"`. They'll be removed no later than Sampling itself.

**Tool-augmented sampling:** the model may return `stopReason:"toolUse"` with `tool_use` blocks; the
server executes them and asks again with matching `tool_result` blocks (same `toolUseId`). Hard rules:
a message containing tool results MUST contain *only* tool results; every `tool_use` MUST be matched
before continuing (else `-32602`); both sides SHOULD impose iteration limits.

**Human-in-the-loop is load-bearing:** the client presents the request for approval, forwards to its
LLM, then presents the generation for review before returning it — "the protocol intentionally limits
server visibility into prompts."

### Roots (Deprecated — SEP-2577)

Filesystem boundaries, typically managed automatically by the host ("the folder the user opened").
Migration path: **pass directories or files via tool parameters, resource URIs, or server config.**

**Capability:** `{ "roots": {} }`. **Root object:** `uri` (**MUST** be `file://`) + optional `name`.
**`notifications/roots/list_changed` was removed** in `2026-07-28` — there's no session to invalidate,
so re-reading roots means asking again on the next request.

**Critical trap — advisory, not a sandbox:** roots "do not enforce security restrictions. Actual
security must be enforced at the operating system level, via file permissions and/or sandboxing." The
spec says servers "SHOULD respect root boundaries," never "MUST enforce," because *servers run code
the client cannot control*. Treat Roots as scoping/UX, never as your only security boundary.

## Utilities

### Logging (Deprecated — SEP-2577)

Server → client log messages. Migration path: **`stderr` on stdio; OpenTelemetry for observability.**

**Capability:** servers emitting log notifications MUST declare `{ "capabilities": { "logging": {} } }`.
Messages are `notifications/message` with RFC 5424 syslog levels
(debug/info/notice/warning/error/critical/alert/emergency).

**`logging/setLevel` was removed.** The level is now **per request**, via
`io.modelcontextprotocol/logLevel` in `_meta` — and the gate is strict: a server **MUST NOT** emit
`notifications/message` for a request that didn't include that field, and MUST NOT deliver log
messages on a `subscriptions/listen` stream (they're request-scoped, so they flow only on the response
stream of the request they belong to).

**Security requirement:** log messages **MUST NOT** contain credentials, secrets, PII, or internal
details that could aid an attacker.

### Pagination

Every `*/list` method paginates identically: an optional `cursor` param, an opaque `nextCursor` in the
result (absent ⇒ last page). The cursor is **server-opaque** — clients MUST NOT parse or construct
one, only pass back what they were given. Page size is server-decided. On an invalid/expired cursor,
discard everything cached for that list and restart from the beginning. Each page is independently
cacheable but **must share one `cacheScope`** — see [caching.md](caching.md).

### Completion

`completion/complete` powers IDE-style autocomplete for prompt arguments and resource-template
variables. **Capability:** `{ "capabilities": { "completions": {} } }`. Params: `ref` — either
`{"type":"ref/prompt","name":…}` or `{"type":"ref/resource","uri":…}` — plus `argument: {name, value}`
(the partial value being typed) and optional `context.arguments` (already-resolved siblings, so
completion can be dependent — completing `framework` differently once `language` is `"python"`).
Result: `completion.{values (max 100), total, hasMore}`. Servers SHOULD debounce/rate-limit and SHOULD
fuzzy-match rather than requiring an exact prefix.

### Progress and Cancellation

A request including a `progressToken` in `_meta` may receive `notifications/progress` pushes. The token
**MUST** be a string or integer, chosen by the client, and unique among active tokens. `progress`
**MUST** increase with each notification even when `total` is unknown; notifications MUST stop after
completion; both sides SHOULD rate-limit.

**Cancellation is now transport-specific** — this changed in `2026-07-28`:
- **Streamable HTTP:** closing the SSE response stream **is** the cancellation signal, and the server
  **MUST** treat a client disconnect as cancellation. No `notifications/cancelled` is sent or expected.
- **stdio:** there's no per-request stream, so the client **MUST** send `notifications/cancelled`
  with the request `id`.

A server may send `notifications/cancelled` for exactly **one** purpose: tearing down a
`subscriptions/listen` stream. Receivers SHOULD stop work, free resources, and not respond; races
where the response was already in flight are expected, and both sides MUST handle them gracefully.
Timeout mechanics are in
[request-model-and-transports.md](request-model-and-transports.md#timeouts).

### Tasks — now an extension, not a primitive

Durable execution with deferred result retrieval and status polling. **Left the core spec in
`2026-07-28`** and lives on as `io.modelcontextprotocol/tasks`, redesigned (SEP-2663): `tasks/get`
polling replaces blocking `tasks/result`, `tasks/update` added for client→server input, `tasks/list`
removed, and servers may return task handles unsolicited without per-request opt-in. `tools` no longer
carry `execution.taskSupport`. Negotiate via `capabilities.extensions` — see
[versioning-and-extensions.md](versioning-and-extensions.md#extensions). Don't assume any
`2026-07-28`-conformant server implements it.

## Terminology glossary

- **Host** — the AI app the user interacts with; coordinates one or more clients.
- **Client** — the protocol connector inside the host; one per server connection.
- **Server** — the program exposing context/capabilities; local (stdio) or remote (Streamable HTTP).
- **Primitive** — a defined unit of capability a client or server offers.
- **Resource template** — a parameterized resource via an RFC 6570 URI template.
- **Model preferences** — abstract model-selection hints; servers can't name an exact model.
- **Modern / Legacy / Dual-era** — see [versioning-and-extensions.md](versioning-and-extensions.md#era-model-modern-legacy-dual-era).
- **MRTR** — Multi Round-Trip Requests; see [mrtr.md](mrtr.md).
- **Confused deputy** / **token passthrough** — see [security.md](security.md).

## Sources (exact URLs fetched, July 2026, `2026-07-28` spec unless noted)

- https://modelcontextprotocol.io/specification/2026-07-28/architecture/index
- https://modelcontextprotocol.io/specification/2026-07-28/basic/index (`resultType`, error-code policy, `_meta`, JSON Schema rules)
- https://modelcontextprotocol.io/specification/2026-07-28/server/tools (deterministic ordering; no `execution.taskSupport`)
- https://modelcontextprotocol.io/specification/2026-07-28/server/resources (`subscriptions/listen` replaces `resources/subscribe`; `-32602`)
- https://modelcontextprotocol.io/specification/2026-07-28/server/prompts
- https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation (Active; no `elicitationId`/`complete`)
- https://modelcontextprotocol.io/specification/2026-07-28/client/sampling (Deprecated banner)
- https://modelcontextprotocol.io/specification/2026-07-28/client/roots (Deprecated banner; no `list_changed`)
- https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/logging (Deprecated; per-request `logLevel` gate)
- https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/{completion,pagination}
- https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/{progress,cancellation}
- https://modelcontextprotocol.io/specification/2026-07-28/deprecated (the authoritative deprecation states above)
- https://modelcontextprotocol.io/extensions/tasks/overview (Tasks as an extension)

If re-verifying: check `/specification/<latest-date>/deprecated` first — it tells you whether Roots /
Sampling / Logging have moved from Deprecated to **Removed**, which is the next change that will
invalidate this file.
