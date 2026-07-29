# Multi Round-Trip Requests (MRTR)

**The pattern that replaced server-initiated requests.** New in `2026-07-28` (SEP-2322) and an
explicit **breaking change**: a server **MUST NOT** send `roots/list`, `sampling/createMessage`, or
`elicitation/create` as its own JSON-RPC request anymore. Instead it *answers* the client's request
with "I need more input," and the client comes back.

This is what makes statelessness possible without a shared store or sticky load balancing: the server
never has to hold a half-finished operation in memory between round trips.

## The flow

1. Client sends a request (`tools/call`, `resources/read`, or `prompts/get`).
2. Server can't finish — it needs user input or an LLM completion. It returns an
   **`InputRequiredResult`** carrying what it needs plus an opaque `requestState`.
   **The original request is now terminated.**
3. Client gathers the inputs (prompting the user, calling its model), then **re-sends the original
   request under a new `id`** with `inputResponses` + the echoed `requestState`.
4. Server reconstitutes its context from `requestState`, finishes, returns a normal result.

The retry is a genuinely independent request — the server processing it needs nothing beyond what's
in it.

## Where the fields live

`inputResponses` and `requestState` are **top-level members of `params`** — siblings of
`name`/`arguments`/`uri`, *not* inside `_meta`. (Verified against `schema.ts`:
`CallToolRequestParams`, `GetPromptRequestParams`, and `ReadResourceRequestParams` all inherit them
from `InputResponseRequestParams`.)

```json
// server -> client: "I need input"
{ "jsonrpc":"2.0","id":2,"result":{
  "resultType":"input_required",
  "inputRequests":{
    "github_login":{"method":"elicitation/create","params":{
      "mode":"form","message":"Please provide your GitHub username",
      "requestedSchema":{"type":"object","properties":{"name":{"type":"string"}},"required":["name"]}}}},
  "requestState":"eyJsb2NhdGlvbiI6Ik5ldyBZb3JrIn0..." }}

// client -> server: same method, NEW id, original params + responses
{ "jsonrpc":"2.0","id":3,"method":"tools/call","params":{
  "name":"get_weather","arguments":{"location":"New York"},
  "inputResponses":{"github_login":{"action":"accept","content":{"name":"octocat"}}},
  "requestState":"eyJsb2NhdGlvbiI6Ik5ldyBZb3JrIn0..." }}
```

## The three types

- **`InputRequests`** — a map. Keys are **server-assigned identifiers**, unique within that request.
  Values **MUST** be one of `ElicitRequest`, `CreateMessageRequest`, or `ListRootsRequest`.
- **`InputResponses`** — the mirror map. Same keys; values are the client's results (`ElicitResult`,
  `CreateMessageResult`, `ListRootsResult`).
- **`InputRequiredResult`** — `resultType: "input_required"` plus optional `inputRequests` and
  optional `requestState`. **At least one of the two MUST be present.**

A `requestState`-only result (no `inputRequests`) is legal and means "nothing to collect, just retry" —
the client MAY retry immediately.

## Only three methods support it

| Method | `InputRequiredResult` allowed |
| --- | --- |
| `tools/call` | Yes |
| `resources/read` | Yes |
| `prompts/get` | Yes |

Servers **MUST NOT** return one on any other request. So there is no MRTR on `tools/list`,
`server/discover`, `completion/complete`, etc.

## Rules that bite

**Client side:**
- The JSON-RPC `id` **MUST** differ between the original and the retry — they are separate requests.
  Reusing the id is a protocol violation, not an optimization.
- Echo `requestState` **byte-for-byte**. **MUST NOT** inspect, parse, modify, or assume anything
  about it. If the server didn't send one, the client **MUST NOT** invent one.
- `inputRequests`/`requestState` apply *only* to the retry of that one request — never attach them to
  a different in-flight request.
- If `inputRequests` is present, the client **MUST** construct the inputs before retrying.

**Server side:**
- **MUST NOT** request a capability the client didn't declare in
  `io.modelcontextprotocol/clientCapabilities` — e.g. no `elicitation/create` in `inputRequests` if
  the client never declared `elicitation`. (The generic version of this is `-32021`
  `MissingRequiredClientCapabilityError`; see
  [request-model-and-transports.md](request-model-and-transports.md#per-request-metadata-_meta).)
- **MUST NOT** assume the client will ever fulfill the request or retry. Design for abandonment.
- **MAY** return `InputRequiredResult` repeatedly across attempts — that's the sanctioned way to
  collect input in several passes.
- If the client returns *incomplete* input, respond with a **new `InputRequiredResult` asking again**
  rather than an error. Reserve JSON-RPC errors for malformed/unparseable input, and ignore extra
  fields you don't recognize.

## `requestState` is attacker-controlled — treat it as such

It round-trips through the client, so a malicious or compromised client can tamper with it to alter
server behavior, bypass authorization, or corrupt logic.

- If `requestState` influences **authorization, resource access, or business logic**, servers **MUST**
  integrity-protect it (HMAC or AEAD) and **MUST** reject state that fails verification. Omitting
  integrity protection is allowed **only** when tampering can cause nothing worse than the request
  failing.
- To bound replay, servers **SHOULD** put these *inside* the protected payload and verify each:
  the **authenticated principal** (reject state presented by a different principal), a short
  **TTL**, and an **identifier for the originating request** (method name + digest of salient
  params — reject state presented on a request that doesn't match).
- Those three bound the replay window and stop cross-user/cross-request reuse but **do not give you
  single-use.** If a given `requestState` must be consumed at most once (one-time redemptions),
  the server **MUST** enforce that invariant server-side.

Encoding is the server's choice — base64 JSON, encrypted JWT, serialized binary. The protocol only
cares that it's an opaque string to everyone else.

## Interaction with caching

Interim and multi-round-trip traffic is **not cacheable**: requests carrying `inputResponses` or
`requestState` **MUST NOT** be cached, and neither may an `input_required` result. Only
`resultType: "complete"` results participate — see [caching.md](caching.md).

## Sources (exact URLs fetched, July 2026, `2026-07-28`)

- https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr
- https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/index
- https://modelcontextprotocol.io/specification/2026-07-28/server/tools (`#input-required-tool-results` — the retry example above)
- https://modelcontextprotocol.io/specification/2026-07-28/server/resources, `.../server/prompts` (same MRTR opt-in wording)
- https://modelcontextprotocol.io/specification/2026-07-28/schema (`InputResponseRequestParams` — confirms `inputResponses`/`requestState` are `params` members, not `_meta`)
- https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/caching (MRTR traffic is non-cacheable)
- https://modelcontextprotocol.io/specification/2026-07-28/client/{elicitation,sampling,roots} (each shows its result "returned inside `inputResponses` on the retried request")
