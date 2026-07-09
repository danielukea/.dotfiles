# MCP Architecture and Primitives

## Architecture

**Host / Client / Server.** The **host** is the AI application the user interacts with (Claude
Code, Claude Desktop, an IDE). The **client** is the protocol-level connector living inside the
host — there is exactly **one client per server connection**, each maintaining a dedicated
session. The **server** is a program that provides context, regardless of where it runs: **local**
servers are spawned as a subprocess and talk over stdio (typically one client); **remote** servers
talk over Streamable HTTP (typically many clients).

**Two-layer model.**
- **Data layer** (inner) — JSON-RPC 2.0-based protocol: lifecycle management plus the primitives below.
- **Transport layer** (outer) — stdio or Streamable HTTP; see [lifecycle-transports-versioning.md](lifecycle-transports-versioning.md).

**JSON-RPC 2.0 wire protocol.** Requests carry `jsonrpc:"2.0"`, `id`, `method`, optional `params`;
responses echo the `id` and carry `result` or `error`. **Notifications** have no `id` and expect
no response, e.g. `{"jsonrpc":"2.0","method":"notifications/initialized"}`. MCP is stateful (a
subset of Streamable HTTP usage can be stateless).

**The `_meta` convention.** Many object types (tool defs, content blocks, requests/results) accept
an optional `_meta` field for out-of-band metadata that isn't part of the primitive's own schema.
Reserved key format: optional reverse-DNS prefix + name (e.g. `modelcontextprotocol.io/foo`); any
prefix whose second-to-last label is `modelcontextprotocol` or `mcp` is reserved for the spec
itself — don't invent keys under that namespace. `_meta` is the carrier both for
[extensions](lifecycle-transports-versioning.md#extensions) and for distributed-tracing context: the
W3C Trace Context fields `traceparent`/`tracestate`/`baggage` travel as reserved `_meta` keys, so a
server can propagate an OpenTelemetry trace across an MCP call without the transport needing to
know about tracing at all (Ruby specifics: `mcp-ruby-sdk`'s server-dsl.md).

## Control-model taxonomy

Every primitive has a clear owner and controller — this is the single most important design fact
for deciding which one to reach for:

| Primitive | Offered by | Controlled by | Role |
| --- | --- | --- | --- |
| **Tools** | Server | **Model** | Functions the LLM invokes to take actions |
| **Resources** | Server | **Application** | Passive, read-only context data |
| **Prompts** | Server | **User** | Reusable templates, explicitly invoked |
| **Sampling** | Client | Server-initiated, user-gated | Server asks the client's LLM for a completion |
| **Roots** | Client | App/User | Filesystem boundaries the server should stay within (advisory) |
| **Elicitation** | Client | Server-initiated, user-gated | Server requests info/confirmation from the user |
| **Logging** | Client | Server-initiated | Server sends log messages to the client |

## Tools

Model-controlled: "the language model can discover and invoke tools automatically based on its
contextual understanding and the user's prompts." Use for anything that *does* something —
mutates state, calls an API, triggers a side effect.

**Methods:** `tools/list` (paginated), `tools/call`. Notification: `notifications/tools/list_changed`.
**Capability:** `{ "capabilities": { "tools": { "listChanged": true } } }`

**Tool definition fields:** `name` (unique; SHOULD be 1–128 chars, `[A-Za-z0-9_.-]`, case-sensitive,
no spaces — these are SHOULDs in the spec, not hard MUSTs, though most SDKs enforce them as if they
were), `title`, `description`, `inputSchema` (JSON Schema object; default dialect is **2020-12**, a
schema MAY override via `$schema`, and servers MUST reject an unsupported dialect gracefully rather
than erroring opaquely; a no-param tool still needs `{"type":"object","additionalProperties":false}`,
never null), optional `outputSchema`, `annotations`, `icons`, `execution.taskSupport` (`"forbidden"`
default / `"optional"` / `"required"`).

**Tool annotations (hints) — exact fields, and what they're *not* for.** `annotations` on a tool
def is a distinct thing from the content `audience`/`priority`/`lastModified` annotations used on
Resources/Prompts/tool-result content (below) — don't conflate the two. The four tool hints, each
optional with a spec default:

| Hint | Default | Meaning |
| --- | --- | --- |
| `readOnlyHint` | `false` | Tool does not modify its environment |
| `destructiveHint` | `true` | May perform destructive updates (meaningful only when `readOnlyHint` is false) |
| `idempotentHint` | `false` | Repeat calls with the same args have no additional effect (meaningful only when `readOnlyHint` is false) |
| `openWorldHint` | `true` | Interacts with an open-ended external world (web search) vs. a closed domain (a memory store) |

The spec is explicit that **these are hints, not guarantees, and are not meant to drive caching or
security decisions**: "Clients should never make tool use decisions based on ToolAnnotations
received from untrusted servers" — a malicious server can claim `readOnlyHint: true` and still
mutate state. Their documented purpose is confirmation-prompt UX and policy/trust decisions, not
caching eligibility (see [caching.md](caching.md) for why treating them as a caching signal is
community inference the spec doesn't endorse).

```json
// tools/call request
{ "jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_weather","arguments":{"location":"New York"}} }
// result
{ "jsonrpc":"2.0","id":2,"result":{
  "content":[{"type":"text","text":"Current weather in New York:\nTemperature: 72°F"}],
  "isError":false } }
```

**Result shape — two kinds of content:**
- **Unstructured** `content` array: `text`, `image` (base64+mimeType), `audio`, `resource_link`
  (a URI pointing at a Resource — **not guaranteed** to appear in `resources/list`), or an
  embedded full `resource`.
- **Structured** `structuredContent` (a JSON object). If the tool declared `outputSchema`, the
  server MUST conform to it and clients SHOULD validate. For backward compat, also serialize the
  same JSON into a `text` content block.

**Two distinct error mechanisms — don't conflate them:**
- **Protocol errors** — a JSON-RPC `error` (e.g. `-32602 "Unknown tool"`). Models rarely recover from these.
- **Tool execution errors** — a *successful* JSON-RPC result with `"isError":true` and actionable
  text. API failures, validation failures, and business-logic failures all belong here — clients
  feed this back to the LLM so it can self-correct. (Clarified explicitly in `2025-11-25`: input
  validation errors are execution errors, not protocol errors.)

**Trap:** tool descriptions/annotations are **not authenticated data** — the spec says clients
"MUST consider tool annotations to be untrusted unless they come from trusted servers." A
malicious or compromised server can embed prompt-injection payloads in a tool's own description.

## Resources

Application-controlled: "resources are application-driven." Passive, **read-only** data that the
*app* — not the model — decides to surface (pickers, search, auto-embedding). No mandated UI.

**Methods:** `resources/list` (paginated), `resources/templates/list`, `resources/read`,
`resources/subscribe` / `resources/unsubscribe`. Notifications: `notifications/resources/list_changed`,
`notifications/resources/updated`.
**Capability:** `{ "capabilities": { "resources": { "subscribe": true, "listChanged": true } } }` —
both flags independent; `{ "resources": {} }` means neither.

**Identity:** a unique URI (RFC 3986) + MIME type. Two discovery patterns: **direct** (fixed URI,
e.g. `calendar://events/2024`) and **resource templates** (RFC 6570 URI templates with params,
e.g. `travel://activities/{city}/{category}`; template args support completion).

```json
// resources/read
{ "jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"file:///project/src/main.rs"} }
// result
{ "jsonrpc":"2.0","id":2,"result":{"contents":[{
  "uri":"file:///project/src/main.rs","mimeType":"text/x-rust",
  "text":"fn main() {\n    println!(\"Hello world!\");\n}"}]} }
```

**Subscribe flow:** `resources/subscribe {uri}` → confirmation; server later pushes
`notifications/resources/updated {uri}`; client re-reads. **Content** is text (`text`) or binary
(`blob`, base64). **Content annotations** (shared with prompts/tool content — a different thing
from the tool *hints* above): `audience` (`["user","assistant"]`), `priority` (0.0–1.0, 1 =
effectively required), `lastModified` (ISO 8601 — **display-only metadata**, e.g. for sorting by
recency; it is not a cache validator, there is no ETag/If-Modified-Since equivalent anywhere in
MCP — see [caching.md](caching.md)).
**URI schemes:** `https://` (only when the client can fetch it directly, not via the server),
`file://`, `git://`, or custom. **Errors:** not found `-32002`, internal `-32603`.

## Prompts

User-controlled: "exposed... with the intention of the user being able to explicitly select them"
— slash commands, command palettes, buttons. **Never auto-triggered.** Use for a curated,
parameterized workflow that showcases how to best combine a server's tools + resources.

**Methods:** `prompts/list` (paginated), `prompts/get`. Notification: `notifications/prompts/list_changed`.
**Capability:** `{ "capabilities": { "prompts": { "listChanged": true } } }`
**Definition fields:** `name`, `title`, `description`, `icons`, `arguments` (`{name, description, required}[]`).

```json
// prompts/get
{ "jsonrpc":"2.0","id":2,"method":"prompts/get","params":{"name":"code_review","arguments":{"code":"def hello():\n    print('world')"}} }
// result
{ "jsonrpc":"2.0","id":2,"result":{"description":"Code review prompt",
  "messages":[{"role":"user","content":{"type":"text","text":"Please review this Python code:\n..."}}]} }
```

`PromptMessage.role` is `"user"` or `"assistant"`; `content` can be `text`, `image`, `audio`, or an
embedded `resource`. Arguments support completion. Errors: invalid name / missing required args →
`-32602`.

## Sampling

Client feature, server-initiated, human-gated. "Sampling allows servers to request LLM
completions through the client... puts the client in complete control of user permissions and
security." Lets a server do AI reasoning **without its own model or API key**.

**Method:** `sampling/createMessage` (server → client).
**Capability (client declares):** basic `{ "sampling": {} }`; with tool calling
`{ "sampling": { "tools": {} } }` (new in `2025-11-25`); `context` sub-capability is soft-deprecated.

**Request params:** `messages`, `modelPreferences` (`hints` — advisory model-name substrings a
client MAY map cross-provider — plus `costPriority`/`speedPriority`/`intelligencePriority` 0–1),
`systemPrompt`, `maxTokens`, optional `tools`+`toolChoice` (`{mode:"auto"|"required"|"none"}`).

```json
{ "jsonrpc":"2.0","id":1,"method":"sampling/createMessage","params":{
  "messages":[{"role":"user","content":{"type":"text","text":"What is the capital of France?"}}],
  "modelPreferences":{"hints":[{"name":"claude-3-sonnet"}],"intelligencePriority":0.8},
  "maxTokens":100 } }
```

**Tool-augmented sampling (`2025-11-25`):** the model may return `stopReason:"toolUse"` with
`tool_use` content blocks; the server executes and replies with a follow-up `sampling/createMessage`
carrying matching `tool_result` blocks (same `toolUseId`). **Hard rules:** a message containing
tool results MUST contain *only* tool results; every `tool_use` MUST be matched before continuing
(else `-32602`); both sides SHOULD impose iteration limits.

**Human-in-the-loop is load-bearing here:** the client presents the request for approval, forwards
to its LLM, then presents the generation for review before returning it — "the protocol
intentionally limits server visibility into prompts."

## Roots

Client feature. Typically managed automatically by the host (e.g. "the folder the user opened"),
with optional manual configuration.

**Method:** `roots/list` (server → client). Notification: `notifications/roots/list_changed`.
**Capability (client declares):** `{ "capabilities": { "roots": { "listChanged": true } } }`
**Root object:** `uri` (MUST be `file://` in the current spec) + optional `name`.

```json
{ "jsonrpc":"2.0","id":1,"result":{"roots":[{"uri":"file:///home/user/projects/myproject","name":"My Project"}]} }
```

**Critical trap — advisory, not a sandbox:** "they do not enforce security restrictions. Actual
security must be enforced at the operating system level, via file permissions and/or sandboxing."
The spec deliberately says servers "SHOULD respect root boundaries," not "MUST enforce," because
*servers run code the client cannot control*. Treat Roots as scoping/UX, never as your only
security boundary. Errors: client doesn't support roots → `-32601`.

## Elicitation

Client feature, server-initiated, human-gated. A server-initiated request for user info, nested
inside another operation. `2025-11-25` split it into **two modes**:

**Method:** `elicitation/create` (server → client).
**Capability (client declares):** `{ "capabilities": { "elicitation": { "form": {}, "url": {} } } }`
(empty object ≡ form only). Client MUST support at least one mode; server MUST NOT send an
unsupported mode.

- **`form` mode** — in-band, structured. Adds `requestedSchema`, a **restricted** JSON Schema
  subset: flat objects, primitives only (string/number/boolean/enum), formats `email`/`uri`/`date`/
  `date-time`, no nested objects or arrays-of-objects.
  ```json
  { "jsonrpc":"2.0","id":2,"method":"elicitation/create","params":{
    "mode":"form","message":"Please provide your contact information",
    "requestedSchema":{"type":"object","properties":{
      "name":{"type":"string"},"email":{"type":"string","format":"email"}},
      "required":["name","email"]}} }
  ```
  Response: `{"action":"accept"|"decline"|"cancel", "content": {...} }` (`content` only on `accept`).
  **Trap: form mode MUST NOT be used to request secrets** (passwords, API keys, tokens, payment
  details) — those require `url` mode.

- **`url` mode** — out-of-band navigation, for sensitive interactions (auth, payment). Adds `url` +
  `elicitationId`. `accept` here means the user *agreed to open the URL* — not that the flow
  completed. The server MAY later push `notifications/elicitation/complete`. A server blocked on a
  pending URL elicitation MAY return `URLElicitationRequiredError` (`-32042`).

## Logging & Tasks

- **Logging** (client feature: server → client log messages) is a **current, active** utility in
  `2025-11-25` — not deprecated. A server that emits log notifications MUST declare the `logging`
  capability (`{"capabilities":{"logging":{}}}`). Clients MAY send `logging/setLevel` to set the
  minimum severity; servers send `notifications/message` (RFC 5424 syslog levels: debug/info/
  notice/warning/error/critical/alert/emergency). Security requirement: log messages MUST NOT
  contain credentials, secrets, PII, or internal details that could aid an attacker. Errors:
  invalid level `-32602`, config error `-32603`.
  **Forward-looking note (not yet in the published spec):** the official Ruby SDK's source
  annotates its logging/sampling/roots helpers as deprecated "as of MCP protocol version
  `2026-07-28` (SEP-2577)" — that date is later than the current `2025-11-25` "Current" revision,
  so this is the SDK anticipating a not-yet-published spec change, not a documented fact of today's
  spec. See `mcp-ruby-sdk`'s testing-and-gotchas.md for that SDK-level detail; don't treat Logging
  as deprecated when reasoning about the protocol itself.
- **Tasks** — durable execution wrappers enabling deferred result retrieval and status polling for
  long-running work; tools opt in via `execution.taskSupport`. Tasks started as an experimental
  feature inside the dated `2025-11-25` core spec, but is now organized as a formal **extension**
  (part of the SEP-2133 Extensions track, evolving on its own repo/timeline) rather than a
  core-spec primitive — see [Extensions](lifecycle-transports-versioning.md#extensions) for the
  current negotiation mechanism. Don't assume every `2025-11-25`-conformant server implements it.

## Other Utilities

**Pagination.** Every `*/list` method (`tools/list`, `resources/list`, `resources/templates/list`,
`prompts/list`) is paginated identically: an optional `cursor` param, an opaque `nextCursor` in the
result (absent ⇒ last page). The cursor is server-opaque — clients MUST NOT parse or construct one,
only pass back what they were given. Page size is entirely server-decided; don't assume a fixed
count. On an invalid/expired cursor, the correct client behavior is to discard everything cached
for that list and restart pagination from the beginning, not to retry the same cursor.

**Completion.** `completion/complete` (client → server) powers IDE-style autocomplete for prompt
arguments and resource-template variables. Capability: `{ "capabilities": { "completions": {} } }`.
Params: `ref` — either `{"type":"ref/prompt","name":...}` or `{"type":"ref/resource","uri":...}` —
plus `argument: {name, value}` (the partial value being typed) and optional `context.arguments`
(already-resolved sibling arguments, so completion can be dependent — e.g. completing a `framework`
argument differently once `language` is already `"python"`). Result:
`completion.{values (max 100), total, hasMore}`. Servers SHOULD debounce/rate-limit and SHOULD
fuzzy-match rather than requiring an exact prefix.

**Progress and Cancellation.** Long-running tool calls pair these two. A request that includes a
`progressToken` in its `_meta` may receive `notifications/progress` pushes
(`progress`/`total`/`message`) from the server while it works. Either side can cancel an in-flight
request by sending `notifications/cancelled` with the original request's `id` — the receiver
SHOULD stop work and MUST NOT send a response for that id afterward (a race where the response was
already in flight is expected and not an error). Recall from
[lifecycle-transports-versioning.md](lifecycle-transports-versioning.md#lifecycle) that a
progress notification MAY reset a request's timeout clock, but a maximum timeout SHOULD still
apply regardless. Ruby-specific mechanics (`MCP::Progress`, `MCP::Cancellation`,
`MCP::CancelledError`) are in `mcp-ruby-sdk`'s server-dsl.md.

## Terminology glossary

- **Host** — the AI app the user interacts with; coordinates one or more clients.
- **Client** — the protocol connector inside the host; one dedicated connection per server.
- **Server** — the program exposing context/capabilities; local (stdio) or remote (Streamable HTTP).
- **Primitive** — a defined unit of capability a client or server offers.
- **Resource template** — a parameterized resource via an RFC 6570 URI template.
- **Model preferences** — abstract model-selection hints; servers can't name an exact model.
- **Confused deputy** / **token passthrough** — see [security.md](security.md).

## Sources (exact URLs fetched, July 2026, `2025-11-25` spec unless noted)

- https://modelcontextprotocol.io/docs/getting-started
- https://modelcontextprotocol.io/docs/learn/architecture
- https://modelcontextprotocol.io/docs/learn/server-concepts
- https://modelcontextprotocol.io/docs/learn/client-concepts
- https://modelcontextprotocol.io/specification/2025-11-25/server/tools
- https://modelcontextprotocol.io/specification/2025-11-25/server/resources
- https://modelcontextprotocol.io/specification/2025-11-25/server/prompts
- https://modelcontextprotocol.io/specification/2025-11-25/client/sampling
- https://modelcontextprotocol.io/specification/2025-11-25/client/roots
- https://modelcontextprotocol.io/specification/2025-11-25/client/elicitation
- https://modelcontextprotocol.io/specification/2025-11-25/server/utilities/logging (confirmed: Logging is active, not deprecated, in the current spec)
- https://modelcontextprotocol.io/specification/2025-11-25/server/utilities/completion
- https://modelcontextprotocol.io/specification/2025-11-25/schema (verified `ToolAnnotations` field names/defaults directly against `schema.ts`)
- https://modelcontextprotocol.io/extensions/overview.md (confirmed: Tasks is organized under the SEP-2133 Extensions track, separate from the dated core spec — see [lifecycle-transports-versioning.md](lifecycle-transports-versioning.md#extensions))
- Forward-looking SDK note sourced from `lib/mcp/server_context.rb` in https://github.com/modelcontextprotocol/ruby-sdk — see `mcp-ruby-sdk` skill, not treated as current spec fact here

If re-verifying: check `/specification/<latest-date>/server/*` and `/client/*` pages — the path
convention is stable even when the date changes.
