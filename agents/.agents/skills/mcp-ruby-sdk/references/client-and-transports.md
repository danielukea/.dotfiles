# MCP Ruby SDK — Client, Transports, and Auth

## `MCP::Client`

Full client, not just a server SDK. Lives in `lib/mcp/client.rb`, transports in `lib/mcp/client/`
(`http.rb`, `stdio.rb`, `oauth.rb`, `oauth/`, `paginated_result.rb`, `tool.rb`).

**Verified public API:**
- `initialize(transport:)` — transport must respond to `send_request`.
- `connect(client_info: nil, protocol_version: nil, capabilities: {})` — runs the `initialize`
  handshake. **Required before any other call** (enforced since 0.23.0 — see
  [testing-and-gotchas.md](testing-and-gotchas.md#gotchas)). Returns the server's `InitializeResult` hash.
- `connected?`, `server_info`
- `tools(cancellation: nil)` → `Array<MCP::Client::Tool>` (auto-paginates); `list_tools(cursor:, meta:, cancellation:)` for a single page
- `call_tool(name: nil, tool: nil, arguments: nil, progress_token: nil, meta: nil, cancellation: nil)` → full JSON-RPC response hash. Accepts either a `tool:` object or a `name:` string.
- `resources` / `list_resources` / `read_resource(uri:)`
- `resource_templates` / `list_resource_templates`
- `prompts` / `list_prompts` / `get_prompt(name:)`
- `complete(ref:, argument:, context: nil)` — completion suggestions
- `ping` → `{}` on success
- `on_elicitation { |params| … }` / `on_sampling { |params| … }` — register handlers for
  server-initiated requests (see [below](#client-side-server-request-handlers))

**Era note:** `connect` runs the `initialize` handshake, and `ping` and server-initiated requests are
legacy-era mechanisms the `2026-07-28` spec removed. They are still the correct API for this gem — see
[testing-and-gotchas.md](testing-and-gotchas.md#version--spec-compatibility--the-era-gap).

**Real usage** (`examples/stdio_client.rb`):

```ruby
transport = MCP::Client::Stdio.new(command: "ruby", args: [server_script])
client = MCP::Client.new(transport: transport)
client.connect

tools = client.tools                                  # => Array<MCP::Client::Tool>
tool  = tools.first                                   # responds to .name, .description
response = client.call_tool(tool: tool, arguments: { a: 5, b: 3 })
content  = response.dig("result", "content")          # note: string keys on call_tool response

client.prompts
client.resources
client.read_resource(uri: "https://test_resource.invalid")
ensure
  transport.close                                     # terminates the subprocess
```

**Trap:** `examples/http_client.rb` is a **hand-rolled `Net::HTTP` JSON-RPC walkthrough** — it does
**not** use `MCP::Client`. Don't mistake it for the SDK's client API; the real examples are
`stdio_client.rb` and `streamable_http_client.rb`.

## Client transports

```ruby
# stdio
stdio = MCP::Client::Stdio.new(command: "bundle", args: ["exec", "ruby", "server.rb"], read_timeout: 30)
client = MCP::Client.new(transport: stdio)

# HTTP — verified constructor (lib/mcp/client/http.rb)
http = MCP::Client::HTTP.new(
  url: "https://api.example.com/mcp",
  headers: { "Authorization" => "Bearer my_token" },
  oauth: nil,                       # an OAuth::Provider; see below
  max_message_bytes: MAX_MESSAGE_BYTES
)
# Faraday customization:
http = MCP::Client::HTTP.new(url: "...") { |faraday| faraday.use MyMiddleware }
```

**Two token-leak guards, both raising `InsecureURLError`, both worth knowing before you debug one:**
- Passing `oauth:` with a non-HTTPS, non-loopback `url` is rejected **at construction** — sending
  bearer tokens over plain http to a remote host would leak them on the wire. Error messages
  canonicalize the URL first so userinfo/query strings can't leak into logs.
- The canonical URL is snapshotted at construction, and a Faraday middleware re-checks the *effective*
  request URL on every call — if middleware or a redirect changes it, the request is refused rather
  than sending the token to a different host.

`max_message_bytes` must be a positive Integer; `nil` or non-positive raises `ArgumentError` (it would
silently make buffering unbounded).

**SSE reconnection (SEP-1699, 0.24.0):** the HTTP client transport resumes a broken stream with the
`Last-Event-ID` header, tracking the last event id and honoring the server's SSE `retry:` field over
its own tuning. Note the era tension — **`2026-07-28` removed resumability entirely**, so this is a
legacy-era capability that only works against servers still implementing it.

## Client-side server-request handlers

Both require a transport that responds to `on_server_request` — i.e. one implementing the **legacy**
server-initiated request mechanism. Neither has a modern-era equivalent in the gem, because
`2026-07-28` servers deliver these through MRTR instead.

```ruby
client.on_elicitation do |params|
  { action: "accept",
    content: MCP::Client::Elicitation.apply_defaults(params["requestedSchema"]) }
end

client.on_sampling { |params| { role: "assistant", content: { ... }, model: "...", stopReason: "endTurn" } }
```

- `on_elicitation` (0.24.0) — `MCP::Client::Elicitation.apply_defaults` fills SEP-1034 schema defaults
  for you.
- `on_sampling` (0.25.0) — carries a YARD `@deprecated` tag citing SEP-2577: register it "only to
  interoperate with servers that still send sampling requests during the deprecation window; new
  servers should call LLM provider APIs directly."
- Either raises `ArgumentError, "The transport does not support server-to-client requests"` if the
  transport can't do it.

**MRTR on the client side — recognized, not automated.** When a server returns an `input_required`
result, the client raises **`MCP::Client::InputRequiredError`** with readers `input_requests`,
`request_state`, and `result`. The source is explicit that "this SDK does not yet drive that resume
loop automatically; callers can inspect `input_requests` and respond manually." So you rescue it,
fulfil each request, and re-issue the original call with `inputResponses` plus the echoed
`request_state` **under a new JSON-RPC id** (protocol rules:
[mrtr.md](../../model-context-protocol/references/mrtr.md)).

Related: **`MCP::Client::SessionExpiredError`** (a `RequestHandlerError`) is raised when the server
answers 404 to a request carrying a session id — per the legacy spec, start over with a fresh
`initialize`. See [client-in-web-server.md](client-in-web-server.md) for why tolerating this is the
right design.

## OAuth

**Verified** (`lib/mcp/client/oauth/provider.rb`):

```ruby
MCP::Client::OAuth::Provider.new(
  client_metadata:,
  redirect_uri:,
  redirect_handler:,
  callback_handler:,
  scope: nil,
  storage: nil,
  client_id_metadata_document_url: nil
)
```

`authorization_flow` returns `:authorization_code`. Attribute readers exist for every kwarg above.
Pass the provider into the HTTP client transport: `MCP::Client::HTTP.new(url: "...", oauth: provider)`.

**Constructor-time validation** (easy to hit): `redirect_uri` MUST be https or a loopback http URL
(`localhost`, `127.0.0.0/8`, `::1`) or you get `InsecureRedirectURIError`, and it MUST already appear in
`client_metadata[:redirect_uris]`. Both are checked before anything else runs.

`lib/mcp/client/oauth.rb` is a namespace file; the full set of components as of 1.0.0:

| File | Provides |
| --- | --- |
| `discovery`, `flow`, `pkce` | PRM discovery, AS metadata discovery, OAuth 2.1 authorization code + PKCE |
| `provider`, `storage_backed_provider`, `in_memory_storage` | the interactive provider and its pluggable token storage |
| `client_credentials_provider` | the `client_credentials` grant (machine-to-machine) |
| `jwt_client_assertion` | **`private_key_jwt` client authentication** (0.24.0) |
| `id_jag_token_exchange`, `cross_app_access_provider` | **SEP-990 Cross-App Access via ID-JAG + the `jwt-bearer` grant** (0.25.0) |

Two spec-conformance changes landed here too, both matching `2026-07-28` requirements:
- **RFC 9207 `iss` validation** (SEP-2468, 0.24.0) — the authorization response's `iss` is validated
  against the recorded issuer before the code is redeemed.
- **Issuer-bound client credentials** (SEP-2352, 0.24.0) — stored credentials are keyed to the AS that
  issued them and are not reused across authorization servers.

Protocol-side rules for all of the above (including why DCR is now deprecated in favor of CIMD):
`model-context-protocol`'s [security.md](../../model-context-protocol/references/security.md).

## `StreamableHTTPTransport`

**Verified constructor** (`lib/mcp/server/transports/streamable_http_transport.rb`):

```ruby
def initialize(
  server,
  stateless: false,
  enable_json_response: false,
  session_idle_timeout: UNSET_IDLE_TIMEOUT,
  max_sessions: DEFAULT_MAX_SESSIONS,
  allowed_origins: nil,
  allowed_hosts: nil,
  dns_rebinding_protection: true,
  session_request_validator: nil,
  max_request_bytes: DEFAULT_MAX_REQUEST_BYTES
)
```

Verified unchanged from 0.23.0 through 1.0.0 — no constructor drift.

- **`stateless: true`** — no session is issued; each POST is self-contained. Required for
  multi-process/multi-instance deployment without sticky sessions (see gotcha in
  [testing-and-gotchas.md](testing-and-gotchas.md#gotchas)). Trade-off: "stateless mode has no
  streams to deliver notifications on," and it doesn't support server-to-client requests.
  Internally it isolates each request in an **ephemeral session** (SEP-2567, 0.21.0), and it makes
  `session_idle_timeout` an error (`ArgumentError`) and `max_sessions` meaningless — both only apply to
  the stateful session store.

  **Do not read `stateless: true` as SEP-2575 statelessness.** It's a deployment escape hatch that
  suppresses session *issuance*; the gem still speaks the legacy handshake protocol underneath. The
  spec's stateless model — per-request `_meta`, no `initialize` at all — is
  [reserved for 2.0](testing-and-gotchas.md#version--spec-compatibility--the-era-gap).
- **`allowed_hosts:` / `allowed_origins:`** — extra `Host`/`Origin` values accepted beyond the
  loopback/same-origin defaults.
- **`dns_rebinding_protection: true`** (default) — validates `Host`/`Origin` headers.

It implements Rack directly: `def call(env); handle_request(Rack::Request.new(env)); end` — so it
mounts anywhere Rack runs. Other public methods: `send_notification(method, params = nil,
session_id: nil, related_request_id: nil)`, `send_request(...)` (blocks for a client response;
raises in stateless mode), `cancel_pending_request(request_id, reason: nil)`, `close`.

```ruby
# bare Rack (examples/streamable_http_server.rb pattern)
server = MCP::Server.new(name: "sse_test_server", tools: [NotificationTool])
transport = MCP::Server::Transports::StreamableHTTPTransport.new(server)
rack_app = Rack::Builder.new do
  use(Rack::Cors) { allow { origins("*"); resource("*", headers: :any,
    methods: [:get, :post, :delete, :options], expose: ["Mcp-Session-Id"]) } }
  run(transport)
end
Rackup::Handler.get("puma").run(rack_app, Port: 9393, Host: "localhost")
```

CORS is the consumer's responsibility — the transport doesn't handle it; examples use `Rack::Cors`
and explicitly expose `Mcp-Session-Id`.

## Framework integration (Rails / Sinatra)

Officially documented in `docs/building-servers.md`. Two patterns:

**Mount as a route** (simplest, stateful by default):

```ruby
server = MCP::Server.new(name: "my_server", tools: [SomeTool, AnotherTool])
transport = MCP::Server::Transports::StreamableHTTPTransport.new(server)
Rails.application.routes.draw { mount transport => "/mcp" }
```

**Per-request server in a controller** (recommended for multi-process or per-user context — stateless):

```ruby
class McpController < ActionController::API
  def create
    server = MCP::Server.new(name: "my_server", tools: [SomeTool],
                             server_context: { user_id: current_user.id })
    transport = MCP::Server::Transports::StreamableHTTPTransport.new(server, stateless: true)
    status, headers, body = transport.handle_request(request)
    render(json: body.first, status: status, headers: headers)
  end
end
```

Both patterns are now documented in the repo `README.md`, and **a complete runnable Rails app ships at
`examples/rails`** — the long-standing request in issue #44, now closed. (Older notes calling this a
doc gap are out of date.)

**Sinatra / plain Rack:** no framework-specific docs exist, but since the transport is a Rack app,
`run(transport)` inside `Rack::Builder` works directly (as shown above); in Sinatra, forward the
request env to `transport.call(env)`. The Rack interface is the integration point everywhere —
there's no Rails engine.

## Sources (fetched 2026-07-29, `main`, gem v1.0.0)

- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client.rb (`InputRequiredError`, `SessionExpiredError`, `on_elicitation`/`on_sampling`)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client/http.rb (verified constructor, `InsecureURLError` guards, SEP-1699 `Last-Event-ID` reconnection)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client/oauth.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client/oauth/provider.rb (constructor + `InsecureRedirectURIError` validation)
- https://api.github.com/repos/modelcontextprotocol/ruby-sdk/contents/lib/mcp/client/oauth (component list incl. `jwt_client_assertion`, `id_jag_token_exchange`, `cross_app_access_provider`)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/server/transports/streamable_http_transport.rb (constructor verified unchanged; `stateless:` semantics)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/README.md (Rails mount + controller patterns; `examples/rails` pointer)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/CHANGELOG.md (which release added each feature)
- https://api.github.com/repos/modelcontextprotocol/ruby-sdk/contents/examples and `/issues/44` (Rails example ships; issue closed)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/examples/stdio_client.rb, `.../streamable_http_server.rb`
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/examples/http_client.rb (confirmed NOT to use `MCP::Client` — hand-rolled `Net::HTTP`)

If re-verifying: the transport/OAuth constructors above were pulled from raw source (highest
confidence) — prefer `lib/mcp/client/oauth/provider.rb` and `lib/mcp/client/http.rb` directly over docs
prose if they ever disagree. The thing most likely to change: whether `on_sampling`/`on_elicitation`
gain a modern-era (MRTR) path, and whether `InputRequiredError` starts driving the resume loop itself.
