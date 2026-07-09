# MCP Lifecycle and Transports

Connection-time concerns: how a session opens (the `initialize` handshake), the two standard
transports that carry it, and how it shuts down. For how the *protocol itself* evolves (dated
versions, negotiation, the Extensions track), see
[versioning-and-extensions.md](versioning-and-extensions.md).

## Lifecycle

Three phases: **Initialization → Operation → Shutdown**. Initialization **MUST** be the first
interaction.

**The handshake (exact sequence):**
1. Client sends `initialize` **request** (must be first; carries `protocolVersion`, `capabilities`, `clientInfo`).
2. Server sends `initialize` **response** (`protocolVersion`, `capabilities`, `serverInfo`, optional `instructions`).
3. Client sends `notifications/initialized` **notification** (no `id`).

```json
// client -> server
{ "jsonrpc":"2.0","id":1,"method":"initialize","params":{
  "protocolVersion":"2025-11-25",
  "capabilities":{"roots":{"listChanged":true},"sampling":{},"elicitation":{"form":{},"url":{}}},
  "clientInfo":{"name":"example-client","version":"1.0.0"}} }

// server -> client
{ "jsonrpc":"2.0","id":1,"result":{
  "protocolVersion":"2025-11-25",
  "capabilities":{"tools":{"listChanged":true},"resources":{"subscribe":true,"listChanged":true}},
  "serverInfo":{"name":"example-server","version":"1.0.0"},
  "instructions":"Optional instructions for the client"} }

// client -> server
{ "jsonrpc":"2.0","method":"notifications/initialized" }
```

`clientInfo`/`serverInfo` is the `Implementation` interface: `name` (programmatic id), `title`
(display name), `version`, plus (new in `2025-11-25`) optional `description`, `icons`, `websiteUrl`.

**Pre-handshake restrictions:** the client SHOULD NOT send requests other than pings before the
server responds to `initialize`; the server SHOULD NOT send requests other than pings/logging
before it receives `notifications/initialized`.

**Capability negotiation:** each side's `capabilities` object lists which primitives (and
sub-features like `listChanged`/`subscribe`) it supports, so neither calls an operation the other
doesn't implement. During Operation, both parties MUST respect the negotiated version and only use
successfully-negotiated capabilities. (The `capabilities.extensions` field negotiated here belongs
to the Extensions track — see [versioning-and-extensions.md](versioning-and-extensions.md#extensions).)

**Shutdown** has no dedicated message — it's transport-level:
- **stdio:** client SHOULD close the child's stdin, wait for exit, `SIGTERM` if it doesn't exit in
  a reasonable time, then `SIGKILL` if still alive. Server MAY initiate by closing stdout and exiting.
- **HTTP:** shutdown = closing the HTTP connection(s).

**Timeouts:** implementations SHOULD set per-request timeouts; on timeout, the sender SHOULD send
a cancellation notification and stop waiting. A progress notification MAY reset the timeout clock,
but a maximum timeout SHOULD always be enforced regardless.

## Transports

Two standard transports: **stdio** and **Streamable HTTP**. Clients SHOULD support stdio whenever
possible. Custom transports are explicitly allowed as long as they preserve JSON-RPC message
format and lifecycle requirements.

### stdio

- Client launches the server as a **subprocess**; server reads JSON-RPC from **stdin**, writes to **stdout**.
- **Framing:** newline-delimited — each line is exactly one JSON-RPC message, and a message
  **MUST NOT contain an embedded newline**.
- **stderr:** server MAY write UTF-8 logs of any level to stderr; the client MAY capture/forward/
  ignore it but SHOULD NOT treat stderr output as an error signal.
- **Channel purity (the #1 stdio footgun):** server MUST NOT write non-MCP content to stdout;
  client MUST NOT write non-MCP content to the server's stdin.
- No network surface by default — this is why stdio doesn't need the OAuth framework (see security.md).

### Streamable HTTP

Replaces the deprecated two-endpoint `HTTP+SSE` transport from `2024-11-05`.

- **Single endpoint model:** one HTTP endpoint (e.g. `https://example.com/mcp`) supports both **POST** and **GET**.
- **POST (client → server):** every JSON-RPC message is its own POST. Client MUST send
  `Accept: application/json, text/event-stream`. If the body is a request, the server MUST respond
  with either `Content-Type: text/event-stream` (opens an SSE stream) or `application/json` (one
  object) — client MUST support both. If the body is a response/notification, server returns
  **202 Accepted** with no body.
- **SSE stream behavior:** server SHOULD send a priming event (an `id`, empty `data`) immediately;
  MAY close the connection at any time (sending a `retry` field first, which the client MUST
  respect) without that meaning the logical stream ended; SHOULD terminate the stream once the
  response is sent. **Disconnection SHOULD NOT be interpreted as cancellation** — to actually
  cancel, the client SHOULD explicitly send a `CancelledNotification`.
- **GET (server → client):** client MAY open a GET (with `Accept: text/event-stream`) for
  unsolicited server messages. Server returns `text/event-stream` or **405** if it offers none.
  Server MUST NOT send a JSON-RPC *response* on a GET stream unless resuming.
- **Multiple connections:** a client MAY hold several SSE streams; the server MUST send each
  message on only **one** stream — no broadcasting the same message to all of them.

**Session handling:**
- Header is **`Mcp-Session-Id`** (exact casing). Server MAY assign it in the `InitializeResult`
  HTTP response; it SHOULD be globally unique and cryptographically secure, and MUST contain only
  visible ASCII (0x21–0x7E).
- If assigned, client MUST echo `Mcp-Session-Id` on every subsequent request. A server requiring a
  session SHOULD return **400** to non-init requests missing it.
- Server MAY terminate a session anytime; afterward it MUST return **404** for that ID. On 404 the
  client MUST start a **fresh** `initialize` (no session id) — not retry the same one.
- Client SHOULD send **HTTP DELETE** with `Mcp-Session-Id` to end a session; server MAY answer
  **405** if it disallows client-initiated termination.

**Resumability:** servers MAY attach an `id` to SSE events (globally unique within the session,
should encode which stream it came from). To resume, client SHOULD issue an **HTTP GET** with the
**`Last-Event-ID`** header — server MAY replay messages after that id **on the same stream only**.
Resumption is always via GET, regardless of whether the original stream was POST- or GET-initiated.

**Protocol version header:** client MUST send `MCP-Protocol-Version: <version>` on all post-init
HTTP requests (SHOULD be the negotiated version). If absent and the server can't otherwise
determine the version, it SHOULD assume **`2025-03-26`**. Invalid/unsupported value → **400**.
(How that version gets negotiated: [versioning-and-extensions.md](versioning-and-extensions.md#versioning).)

**Origin validation:** servers MUST validate the `Origin` header on all connections (DNS-rebinding
defense); invalid → **403**. Local servers SHOULD bind only to `127.0.0.1`, never `0.0.0.0`, and
SHOULD still implement auth.

**Backward compat (interop only):** the deprecated `2024-11-05` transport used *separate* SSE and
POST endpoints plus an `endpoint` event. Detection: client POSTs `InitializeRequest`; success ⇒
new transport; `400/404/405` ⇒ fall back to a GET expecting an SSE `endpoint` event ⇒ old
transport. Servers wanting to support old clients keep both old endpoints alongside the new one.

## Sources (exact URLs fetched, July 2026)

- https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle
- https://modelcontextprotocol.io/specification/2025-11-25/basic/transports

If re-verifying: check `/specification/<latest-date>/basic/lifecycle` and `.../basic/transports` —
the path convention is stable even when the date changes.
