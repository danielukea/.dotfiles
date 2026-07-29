# MCP Request Model and Transports

How a single request carries everything a server needs, and the two transports that deliver it.

**`2026-07-28` removed the connection-oriented model.** There is no `initialize` handshake, no
`notifications/initialized`, no session, and no three-phase lifecycle. If you are looking for those,
you are looking for a **Legacy**-era revision (`2025-11-25` and earlier) — see
[versioning-and-extensions.md](versioning-and-extensions.md#era-model-modern-legacy-dual-era).

## Statelessness — the rule everything else follows from

> "all the information needed to process a request is contained in the request itself. A server
> processes each request independently; no state should be inferred from previous requests, **even
> those on the same connection or stream**."

Consequences the spec spells out:

- Servers **MUST NOT** rely on prior requests over the same connection to establish capabilities,
  protocol version, or client identity. Every request supplies them in `_meta`.
- Servers **SHOULD NOT** require a client to reuse the same connection or process for related
  operations, and **SHOULD** expect requests from multiple tasks/threads/conversations interleaved.
- State spanning requests (long-running work, application handles) **MUST** be referenced by an
  **explicit identifier the client passes on each request**.
- **A connection is not a conversation.** An open stdio process is not a session; a server must not
  treat process or connection identity as a proxy for conversation continuity.

`subscriptions/listen` is not an exception — it's still request/response, where the response happens
to be a long-lived stream. Its state is scoped to *the request*, not the connection under it.

## Per-request metadata (`_meta`)

Every client request carries its own protocol context. This is what replaced the handshake.

| Key | Type | Required | Purpose |
| --- | --- | --- | --- |
| `io.modelcontextprotocol/protocolVersion` | `string` | **Yes** | Version for *this* request, e.g. `"2026-07-28"` |
| `io.modelcontextprotocol/clientCapabilities` | `ClientCapabilities` | **Yes** | Capabilities relevant to this request |
| `io.modelcontextprotocol/clientInfo` | `Implementation` | No (SHOULD) | Client name/version |
| `io.modelcontextprotocol/logLevel` | `LoggingLevel` | No | Minimum log level for this request — **gates `notifications/message` entirely** |

Results carry `io.modelcontextprotocol/serverInfo` (SHOULD). Other reserved keys: `progressToken`
(opts into progress), `io.modelcontextprotocol/subscriptionId` (correlates subscription
notifications), and — as an explicit exception to the prefix rule — `traceparent` / `tracestate` /
`baggage` for W3C Trace Context.

```json
{ "jsonrpc":"2.0","id":1,"method":"tools/call","params":{
  "name":"get_weather","arguments":{"location":"Seattle, WA"},
  "_meta":{
    "io.modelcontextprotocol/protocolVersion":"2026-07-28",
    "io.modelcontextprotocol/clientInfo":{"name":"ExampleClient","version":"1.0.0"},
    "io.modelcontextprotocol/clientCapabilities":{}}}}
```

**Failure modes, all `400 Bad Request` on HTTP:**
- Missing a required `_meta` field ⇒ malformed ⇒ **`-32602`** (Invalid params).
- Server needs a capability the client didn't declare ⇒ **`-32021`
  `MissingRequiredClientCapabilityError`**, with `data.requiredCapabilities` listing what's missing.
  A server **MUST NOT** rely on undeclared capabilities.
- Unsupported version ⇒ **`-32022` `UnsupportedProtocolVersionError`** (see
  [versioning-and-extensions.md](versioning-and-extensions.md#versioning)).

`clientInfo`/`serverInfo` are **self-reported and unverified** — for display, logging, and debugging
only. Implementations **SHOULD NOT** branch behavior on them and **SHOULD NOT** use them for
security decisions.

## `server/discover`

The one mandatory RPC: **servers MUST implement it.** Clients **MAY** call it — it is *not* a
handshake, and skipping it is legal (just send the request you wanted and handle a version error).

Two reasons to call it anyway: to show a user the server's identity/capabilities in one round trip
instead of probing `tools/list` + `prompts/list` + `resources/list`, and as the **stdio
backward-compatibility probe** (below).

Request takes no params beyond `_meta`. `DiscoverResult` returns `supportedVersions`,
`capabilities`, optional `instructions` (natural-language guidance for the LLM), `serverInfo` in
`_meta` — and it is **cacheable** (`ttlMs`/`cacheScope`, see [caching.md](caching.md)).

## Transports

Two standard transports: **stdio** and **Streamable HTTP**. Custom transports remain allowed if they
preserve the JSON-RPC framing and message rules.

### stdio

Mostly unchanged from earlier revisions — the framing and channel-purity rules are the durable part:

- Client launches the server as a **subprocess**; JSON-RPC over stdin/stdout, **newline-delimited**,
  no embedded newlines.
- **stdout is protocol-only.** Server MUST NOT write non-MCP content to stdout; client MUST NOT
  write non-MCP content to stdin. Any stray `print`/banner garbles the stream.
- **stderr:** any log level, free-form UTF-8; the client SHOULD NOT read stderr output as an error
  signal. With Logging deprecated, stderr is now the *recommended* logging path for stdio servers.
- **One shared channel, no per-request streams.** Everything is multiplexed: responses (by `id`),
  request-scoped notifications, and subscription notifications (correlate via
  `io.modelcontextprotocol/subscriptionId`).
- Server **MUST NOT** write JSON-RPC *requests* to stdout — server→client interactions go through
  [MRTR](mrtr.md) instead.
- **Cancellation is `notifications/cancelled`** (there's no stream to close).
- **Shutdown:** client closes stdin, waits, then escalates (`SIGTERM` → `SIGKILL` on POSIX;
  `TerminateProcess`/Job Objects on Windows). Servers SHOULD exit promptly on stdin EOF — it's the
  only portable graceful-shutdown signal. Server MAY initiate by closing stdout and exiting.
- **Unexpected exit is cheap now:** restart and retry. Because the protocol is stateless there's no
  session to rebuild — but active `subscriptions/listen` streams must be re-established.

The framing is transport-agnostic: the same newline-delimited JSON-RPC works over Unix sockets or
TCP, and custom transports SHOULD reuse it, supplying their own equivalents only for the
subprocess-specific parts (launch, stderr, shutdown, restart).

### Streamable HTTP

**POST-only, single endpoint.** The GET stream and DELETE are gone.

- Every JSON-RPC message is its own **POST**. Client MUST send
  `Accept: application/json, text/event-stream` and the required metadata headers (below).
- Body is a single request or notification; the client **MUST NOT** send JSON-RPC responses.
- Request ⇒ server returns `application/json` (one object) **or** `text/event-stream` (an SSE stream
  scoped to that request). Client MUST support both.
- Notification ⇒ **202 Accepted**, no body (or an HTTP error if unacceptable).
- **No client→server notifications exist in the core protocol over HTTP.** The only one,
  `notifications/cancelled`, is stdio-only.
- **On an SSE response stream:** the server MAY send `notifications/progress` /
  `notifications/message` that relate to *that* request, then the final response, which SHOULD
  terminate the stream. The server **MUST NOT** send independent JSON-RPC requests on it.
- Servers **SHOULD** send `X-Accel-Buffering: no` when opening SSE, or reverse proxies (nginx) will
  buffer events. For long-lived streams, emit periodic SSE comment lines (`:\r\n`) as keep-alive.
- **Origin validation:** servers MUST validate `Origin`; invalid ⇒ **403**. Bind local servers to
  `127.0.0.1`, not `0.0.0.0`, and still implement auth.

**No sessions.** `Mcp-Session-Id` does not exist in this revision, list endpoints no longer vary
per-connection, and there is nothing to terminate. Cross-call state is a **server-minted handle
passed as an ordinary tool argument** — application data, not protocol machinery.

**No resumability.** SSE event `id`s and `Last-Event-ID` are gone. A broken response stream loses
the in-flight request; the client **MUST** re-issue it as a **new request with a new request ID**.

**Cancellation reversed from `2025-11-25`:** closing the SSE response stream **MUST** be treated by
the server as cancellation of that request. Because each request owns its stream, the disconnect is
unambiguous. (The previous revision said the opposite — disconnection SHOULD NOT mean cancellation.)

#### Required headers

The transport mirrors body fields into headers so load balancers, gateways, and observability tools
can route and inspect without parsing the body.

| Header | Source field | Required for |
| --- | --- | --- |
| `MCP-Protocol-Version` | `_meta.io.modelcontextprotocol/protocolVersion` | every POST |
| `Mcp-Method` | `method` | all requests |
| `Mcp-Name` | `params.name` or `params.uri` | `tools/call`, `resources/read`, `prompts/get` |

Servers **MUST** reject a header/body mismatch — or a missing required header — with **400** +
**`-32020` `HeaderMismatch`**. That's the whole point: a load balancer routing on the header and a
server executing on the body must not be able to disagree. Compare integers numerically (`42.0` ==
`42`), and decode Base64-sentinel values before comparing.

Servers **MAY** mark tool parameters with **`x-mcp-header`** in `inputSchema` to mirror them into
`Mcp-Param-{Name}` headers; **clients MUST support this.** Constraints worth knowing: primitive
types only (`number` excluded — `integer`/`string`/`boolean` only), case-insensitively unique, and
**statically reachable through `properties` chains only** — never through `items`, `oneOf`/`anyOf`/
`allOf`/`not`, `if`/`then`/`else`, or `$ref`. A violating annotation invalidates the tool definition,
and clients **MUST** drop that one tool from `tools/list` results (SHOULD log why) rather than fail
the whole list.

Values that can't be plain ASCII use the sentinel `=?base64?{base64 of UTF-8}?=` — lowercase,
exact. This applies to `Mcp-Name` too, and a literal value that happens to match the sentinel
pattern MUST itself be encoded to avoid ambiguity.

#### Status codes

| Situation | Response |
| --- | --- |
| Notification accepted | `202 Accepted`, no body |
| Header/body mismatch, missing header, malformed `_meta` | `400` + `-32020` / `-32602` |
| Unsupported protocol version | `400` + `-32022` (with `data.supported`) |
| Missing client capability | `400` + `-32021` (with `data.requiredCapabilities`) |
| **Unknown RPC method** | **`404`** + `-32601` |
| Invalid `Origin` | `403` |
| GET or DELETE on the MCP endpoint | `405` |

The `404`-with-a-JSON-RPC-error shape is deliberate: it distinguishes "modern server, unknown
method" from a legacy HTTP+SSE server that simply doesn't host this endpoint.

A modern-only server receiving legacy traffic **SHOULD** ignore `Mcp-Session-Id` (never mint or echo
one), ignore `Last-Event-ID`, and answer GET/DELETE with `405`.

## `subscriptions/listen`

Replaces **both** the HTTP GET stream and `resources/subscribe`/`resources/unsubscribe`. One
long-lived request whose response *is* the notification stream.

Client opts into specific types — the server **MUST NOT** send types it wasn't asked for:

| Field | Type | Delivers |
| --- | --- | --- |
| `toolsListChanged` | `boolean` | `notifications/tools/list_changed` |
| `promptsListChanged` | `boolean` | `notifications/prompts/list_changed` |
| `resourcesListChanged` | `boolean` | `notifications/resources/list_changed` |
| `resourceSubscriptions` | `string[]` | `notifications/resources/updated` for those URIs |

```json
{ "jsonrpc":"2.0","id":1,"method":"subscriptions/listen","params":{
  "notifications":{"toolsListChanged":true,
                   "resourceSubscriptions":["file:///project/config.json"]}}}
```

- Server **MUST** send `notifications/subscriptions/acknowledged` **first**, and MUST NOT send any
  subscription notification before it. Its `notifications` field is the subset the server actually
  agreed to honor — **check it against what you asked for**; unsupported types are silently omitted.
- **The subscription ID is the JSON-RPC `id` of the `listen` request**, echoed in
  `io.modelcontextprotocol/subscriptionId` on every message. On stdio (one shared channel) clients
  **MUST** use it to demultiplex. Multiple concurrent subscriptions are allowed.
- **Request-scoped notifications never appear here.** `notifications/progress` and
  `notifications/message` flow only on the response stream of the request they belong to.
- **Ending it:** client closes the SSE stream (HTTP) or sends `notifications/cancelled` referencing
  the listen request id (stdio). A server tearing it down SHOULD first respond to the original
  request with an empty `resultType: "complete"` result — that's the *graceful*-close signal; a
  stream that just drops carries no response and MAY be treated as a reconnect trigger. (The
  cancellation page also requires a server-sent `notifications/cancelled` referencing the listen
  request when a server tears a subscription down — the only purpose for which a server may send
  that notification.)
- On stdio, after a reconnect the client **MUST** re-send `subscriptions/listen` — the server holds
  no subscription state across connections.

## Timeouts

Implementations SHOULD set per-request timeouts, and on expiry cancel via the transport's mechanism
(close the stream on HTTP; `notifications/cancelled` on stdio). A progress notification **MAY** reset
the clock, but a maximum timeout SHOULD always be enforced regardless. SDKs SHOULD make this
per-request configurable.

## Sources (exact URLs fetched, July 2026, `2026-07-28`)

- https://modelcontextprotocol.io/specification/2026-07-28/basic/index (statelessness, `_meta`, error-code policy)
- https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/index
- https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio
- https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/streamable-http
- https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/subscriptions
- https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/cancellation
- https://modelcontextprotocol.io/specification/2026-07-28/server/discover

If re-verifying: `/specification/<latest-date>/basic/lifecycle` **no longer exists** — the paths are
now `basic/index`, `basic/transports/{stdio,streamable-http}`, and `basic/patterns/*`.
