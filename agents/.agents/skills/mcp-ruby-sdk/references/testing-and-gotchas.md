# MCP Ruby SDK — Testing, Version Compatibility, and Gotchas

## Testing

The SDK's own suite (`test/mcp/server_test.rb`) tests entirely **in-process, no transport** — this
is the idiomatic way to test a server you build with it:

```ruby
request = { jsonrpc: "2.0", method: "tools/list", id: 1 }
response = @server.handle(request)          # => response hash (symbol keys)
assert_equal "test_tool", response[:result][:tools][0][:name]

request = { jsonrpc: "2.0", method: "tools/call",
            params: { name: tool_name, arguments: tool_args }, id: 1 }
response = @server.handle(request)
assert_equal tool_response.to_h, response[:result]
```

Two entry points: **`server.handle(hash)`** → response hash, and **`server.handle_json(json_string)`**
→ JSON string (parse with `symbolize_names: true`). There is **no dedicated test-double transport**
shipped — the design intent is that you drive the server directly with `handle`/`handle_json`
instead of standing up a real transport in tests. You can also unit-test a Tool class in isolation:
`MyTool.call(**args, server_context: nil)`.

Test files for reference: `test/test_helper.rb`, `test/json_rpc_handler_test.rb`,
`test/instrumentation_test_helper.rb`, `test/mcp/`.

**The transport-parsing gotcha, in full:** transports parse incoming JSON with
`symbolize_names: true`, so tool args arrive as **symbol-keyed hashes at every nesting level** —
`payload[:subject]`, never `payload["subject"]`. To make a unit test match real transport
delivery, round-trip the arguments through JSON first:

```ruby
delivered = JSON.parse(JSON.generate(arguments), symbolize_names: true)
MyTool.call(**delivered, server_context: nil)
```

## Version / spec compatibility

**Verified from `lib/mcp/configuration.rb`:**

```ruby
LATEST_STABLE_PROTOCOL_VERSION = "2025-11-25"
SUPPORTED_STABLE_PROTOCOL_VERSIONS = [
  LATEST_STABLE_PROTOCOL_VERSION, "2025-06-18", "2025-03-26", "2024-11-05",
]
DEFAULT_NEGOTIATED_PROTOCOL_VERSION = "2025-03-26"
```

The `protocol_version` getter returns `@protocol_version || LATEST_STABLE_PROTOCOL_VERSION` — if
you don't set one explicitly, the gem defaults to the **latest** stable version, not the
negotiation fallback. `DEFAULT_NEGOTIATED_PROTOCOL_VERSION` (`"2025-03-26"`) matches the spec's own
rule for what an HTTP server should assume when the `MCP-Protocol-Version` header is absent (see
`model-context-protocol`'s
[lifecycle-and-transports.md](../../model-context-protocol/references/lifecycle-and-transports.md#transports)).
Setting an unsupported version raises `ArgumentError` — the list above is exhaustive, not a
"probably works" guess.

Override with `MCP::Configuration.new(protocol_version: "2024-11-05")` if you need to target an
older client.

## Gotchas

Grounded in CHANGELOG + source; issue numbers cited where used.

| Symptom | Real cause | Fix / workaround |
| --- | --- | --- |
| Tool receives `nil` for `payload["key"]` but the data is present | `symbolize_names: true` parsing at every depth | Use `payload[:key]`; round-trip test args through `JSON.generate`/`JSON.parse(..., symbolize_names: true)` |
| Sessions/notifications break under Puma `workers > 0` or behind a load balancer | `StreamableHTTPTransport` holds session + SSE state in memory, single-process only | Run single-process (`workers 0`), use sticky sessions, or pass `stateless: true` (trades away notifications / server→client requests) |
| stdio client requests hang or error "not connected" | 0.23.0 **requires** `MCP::Client#connect` before sending requests (implicit stdio init deprecated 0.18.0, enforced 0.23.0) | Call `client.connect` first |
| `server_context` Roots/Sampling helpers emit deprecation warnings | 0.23.0's own source comments cite **SEP-2577** (open issue **#390**), ahead of a spec revision (`2026-07-28`) later than today's published `2025-11-25` "Current" spec | This is the SDK getting ahead of an anticipated change, not a documented protocol deprecation today — fine to keep using them for now, but expect a migration path to land; don't tell users "Logging is deprecated in MCP" (it isn't — see `model-context-protocol`) |
| `require "mcp/transports"` fails | `MCP::Transports` module **removed in 0.15.0** | Use `MCP::Server::Transports::StdioTransport` / `StreamableHTTPTransport` |
| `Server#notify_progress` / `#create_sampling_message` undefined | Broadcast progress API removed 0.10.0; direct `create_sampling_message` removed 0.13.0 | Use the per-connection `server_context` helpers (see [server-dsl.md](server-dsl.md#server-side-advanced-server_context)) |
| HTTP request rejected as too large, or stdio memory grows unbounded | DoS hardening added in 0.23.0: bounded request body, bounded stdio line reads (`max_line_bytes`, default 4 MiB), bounded session retention | Tune `max_request_bytes:` / `max_line_bytes:` if you legitimately need larger payloads |
| Cross-origin or wrong-Host requests rejected | DNS-rebinding protection (Host/Origin validation) is on by default since 0.23.0 | Whitelist via `allowed_hosts:` / `allowed_origins:` on `StreamableHTTPTransport` |
| `SyntaxError` on Ruby 2.7.0 | Argument-forwarding syntax bug, fixed in 0.22.0 | Upgrade to ≥ 0.22.0 |
| No Rails example ships in the repo | Long-standing doc request, issue **#44** | The transport is a Rack app — `mount transport => "/mcp"` (see [client-and-transports.md](client-and-transports.md#framework-integration-rails--sinatra)) |

## Maturity signals

- **Version 0.23.0, pre-1.0** — API is still evolving; treat as unstable and pin the version.
  Frequent breaking changes across minor versions (module removals in 0.10.0/0.13.0/0.15.0, the
  0.23.0 handshake requirement change).
- **Very active:** ~727 commits, ~23 minor releases in ~14 months, roughly weekly/biweekly cadence.
- **Official and backed:** the official MCP-org SDK, built with Shopify; ships a conformance test
  suite (since 0.8.0) and tracks protocol SEPs closely.
- **Low bug backlog:** open issues are almost entirely SEP protocol-proposal tracking tickets
  (enhancements), not defects — e.g. #44, #390, #98, #382, #389, #391, #386, #387, #381, #385, #376.
- No explicit semver-stability guarantee is published — read the CHANGELOG before bumping the
  version in production.

## Sources (fetched 2026-07-09, `main`, gem v0.23.0)

- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/test/mcp/server_test.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/configuration.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/CHANGELOG.md
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/version.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/docs/building-servers.md
- https://github.com/modelcontextprotocol/ruby-sdk/issues?q=is%3Aissue+is%3Aopen (issues #44, #390, #98, #382, #389, #391, #386, #387, #381, #385, #376)

If re-verifying against a newer release: read `CHANGELOG.md` top-to-bottom first — the version
list and every removed/deprecated API above is exactly the kind of thing that changes between
minor versions on a pre-1.0 gem.
