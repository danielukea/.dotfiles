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

# HTTP
http = MCP::Client::HTTP.new(
  url: "https://api.example.com/mcp",
  headers: { "Authorization" => "Bearer my_token" }
)
# Faraday customization:
http = MCP::Client::HTTP.new(url: "...") { |faraday| faraday.use MyMiddleware }
```

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

`lib/mcp/client/oauth.rb` is just a namespace file requiring: `oauth/discovery`, `oauth/flow`,
`oauth/in_memory_storage`, `oauth/pkce`, `oauth/storage_backed_provider`, `oauth/provider`,
`oauth/client_credentials_provider` — supporting "PRM discovery, Authorization Server metadata
discovery, Dynamic Client Registration, OAuth 2.1 Authorization Code + PKCE, and the
`client_credentials` grant," per the protocol's authorization spec (see `model-context-protocol`'s
[security.md](../../model-context-protocol/references/security.md)).

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

- **`stateless: true`** — no session is issued; each POST is self-contained. Required for
  multi-process/multi-instance deployment without sticky sessions (see gotcha in
  [testing-and-gotchas.md](testing-and-gotchas.md#gotchas)). Trade-off: "stateless mode has no
  streams to deliver notifications on," and it doesn't support server-to-client requests.
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

**Sinatra / plain Rack:** no framework-specific docs exist, but since the transport is a Rack app,
`run(transport)` inside `Rack::Builder` works directly (as shown above); in Sinatra, forward the
request env to `transport.call(env)`. The Rack interface is the integration point everywhere —
there's no Rails engine.

## Sources (fetched 2026-07-09, `main`, gem v0.23.0)

- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client/oauth.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client/oauth/provider.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/server/transports/streamable_http_transport.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/examples/stdio_client.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/examples/streamable_http_server.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/examples/http_client.rb (confirmed NOT to use `MCP::Client` — hand-rolled `Net::HTTP`)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/docs/building-clients.md
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/docs/building-servers.md

If re-verifying: the transport/OAuth constructors above were pulled from raw source (highest
confidence). `docs/building-clients.md` does not document OAuth in real depth — always prefer
`lib/mcp/client/oauth/provider.rb` directly over the docs prose if they ever disagree.
