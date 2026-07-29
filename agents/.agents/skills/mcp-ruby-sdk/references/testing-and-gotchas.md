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

## Version / spec compatibility — the era gap

**Verified from `lib/mcp/configuration.rb` (still true at 1.0.0):**

```ruby
LATEST_STABLE_PROTOCOL_VERSION = "2025-11-25"
SUPPORTED_STABLE_PROTOCOL_VERSIONS = [
  LATEST_STABLE_PROTOCOL_VERSION, "2025-06-18", "2025-03-26", "2024-11-05",
]
DEFAULT_NEGOTIATED_PROTOCOL_VERSION = "2025-03-26"
```

**`2026-07-28` is absent from that list, and that is the headline compatibility fact.** The gem is a
**Legacy-era** implementation in the spec's own
[Modern/Legacy/Dual-era](../../model-context-protocol/references/versioning-and-extensions.md#era-model-modern-legacy-dual-era)
vocabulary: it establishes state with an `initialize` handshake and HTTP sessions. `ROADMAP.md` states
the plan directly — additive `2026-07-28` features ship opt-in during 1.x, while "breaking parts of
that revision, such as the SEP-2575 stateless lifecycle rewrite, are reserved for 2.0."

**What that means when a modern client meets this gem.** The gem *does* answer `server/discover`, so a
dual-era client's probe succeeds — but the `supportedVersions` it returns is
`SUPPORTED_STABLE_PROTOCOL_VERSIONS`, which tops out at `2025-11-25`. A client asking for
`2026-07-28` therefore learns "modern-looking server, but pick an older version" and drops back to the
legacy handshake. That's the dual-era fallback path working as designed, not a failure.

The `protocol_version` getter returns `@protocol_version || LATEST_STABLE_PROTOCOL_VERSION` — if you
don't set one explicitly, the gem defaults to the **latest** stable version, not the negotiation
fallback. `DEFAULT_NEGOTIATED_PROTOCOL_VERSION` (`"2025-03-26"`) matches the legacy-era rule for what an
HTTP server should assume when the `MCP-Protocol-Version` header is absent (see `model-context-protocol`'s
[request-model-and-transports.md](../../model-context-protocol/references/request-model-and-transports.md#required-headers)
— note that in `2026-07-28` that header is *required*, and this fallback only applies to older clients).
Setting an unsupported version raises `ArgumentError` — the list above is exhaustive, not a "probably
works" guess.

Override with `MCP::Configuration.new(protocol_version: "2024-11-05")` if you need to target an older
client.

### Which `2026-07-28` features the gem already has

Additive only — none of them change the handshake or session model:

| Feature | SEP | Landed | Shape in the gem |
| --- | --- | --- | --- |
| `server/discover` | SEP-2575 | 0.24.0 | `Methods::SERVER_DISCOVER` → `Server#discover`; state-free and idempotent, answers before/without `initialize`. Returns `supportedVersions`/`capabilities`/`serverInfo`/`instructions` — **no `ttlMs`/`cacheScope`** (the source says so explicitly) |
| MRTR `input_required` | SEP-2322 | 0.24.0 | Recognized on the **client** side only, as `MCP::Client::InputRequiredError`. **The SDK does not drive the resume loop** — inspect `input_requests`/`request_state` and re-issue yourself |
| `ttlMs` / `cacheScope` | SEP-2549 | 0.24.0 | `MCP::Server.new(ttl_ms:, cache_scope:)` + writers. **Opt-in:** with both `nil`, results serialize exactly as before |
| Capability `extensions` | SEP-2133 | 0.21.0 | Advertised in capabilities |
| Ephemeral-session isolation for stateless requests | SEP-2567 | 0.21.0 | Internal to `StreamableHTTPTransport`'s `stateless:` mode |
| `Mcp-Method` / `Mcp-Name` headers | SEP-2243 | 0.22.0 | Sent by the client transport |
| JSON Schema 2020-12 tool schemas | SEP-2106 | 0.22.0 | Conformed |
| W3C trace context in `_meta` | SEP-414 | 0.20.0 | `MCP::TraceContext` |

Two source comments to discount when reading the gem: it still describes `2026-07-28` as a **"draft"**
(it was published 2026-07-28) and cites SEP PR URLs rather than the released spec.

### Release history since 0.23.0

- **1.0.0** (2026-07-24) — first stable release. Adds `ROADMAP.md` (#465) and `VERSIONING.md` (#466);
  no functional changes. Public API now stable per SemVer, with the conformance/security/defect
  exceptions below.
- **0.25.0** (2026-07-18) — SEP-990 Cross-App Access via ID-JAG + the `jwt-bearer` grant (#454);
  client-side sampling via `MCP::Client#on_sampling` (#458). Fixes: reject notifications carrying an
  unknown/expired session (#455), handle an `initialize` request sent without an id (#456), bound
  client-side message buffering in the HTTP transport (#459), lowercase response header names in
  `StreamableHTTPTransport` (#460).
- **0.24.0** (2026-07-12) — SEP-1699 SSE reconnection in the HTTP client transport (#426); RFC 9207
  `iss` validation (SEP-2468, #431); `private_key_jwt` for `client_credentials` (#432); MRTR
  `input_required` recognition (#433); opt-in `ttlMs`/`cacheScope` (#436); `server/discover` +
  stateless lifecycle error codes (#438); SEP-2260 associating server→client requests with the
  originating client request (#440); server-side MCP Apps helpers (SEP-1865, #441); client-side
  elicitation with SEP-1034 schema defaults (#443); class-based `Resource`/`ResourceTemplate` (#447).
  **Changed:** stored client credentials bound to the AS issuer (SEP-2352, #439).

**`VERSIONING.md`, the part that matters:** minor releases avoid incompatible changes, *but* the SDK's
primary contract is spec conformance — so behavior deviating from the MCP spec is treated as a bug and
**may be fixed incompatibly in a minor release**, as may security vulnerabilities and clear defects.
"1.0 means stable" is true, with that asterisk.

## Gotchas

Grounded in CHANGELOG + source; issue numbers cited where used.

| Symptom | Real cause | Fix / workaround |
| --- | --- | --- |
| Tool receives `nil` for `payload["key"]` but the data is present | `symbolize_names: true` parsing at every depth | Use `payload[:key]`; round-trip test args through `JSON.generate`/`JSON.parse(..., symbolize_names: true)` |
| Sessions/notifications break under Puma `workers > 0` or behind a load balancer | `StreamableHTTPTransport` holds session + SSE state in memory, single-process only | Run single-process (`workers 0`), use sticky sessions, or pass `stateless: true` (trades away notifications / server→client requests) |
| stdio client requests hang or error "not connected" | 0.23.0 **requires** `MCP::Client#connect` before sending requests (implicit stdio init deprecated 0.18.0, enforced 0.23.0) | Call `client.connect` first |
| Expecting a runtime deprecation warning from the `server_context` Roots/Sampling/Logging helpers (or `Client#on_sampling`) — and not seeing one | These are **YARD `@deprecated` doc tags only** (`lib/mcp/server_context.rb`, `lib/mcp/client.rb`), citing SEP-2577. There is no `Kernel#warn` behind them. `ROADMAP.md`: the three features "remain fully supported throughout 1.x, and deprecation warnings will be added in a future minor release" | Nothing to fix — keep using them. Don't promise a warning that won't appear. The *protocol* deprecation is now real (`2026-07-28`, SEP-2577, earliest removal on/after 2027-07-28), so "deprecated in MCP" is correct today; "deprecated in the gem at runtime" is not |
| Assuming spec-removed features are gone from the gem | Spec removal doesn't oblige an SDK to drop anything — that's the SDK's own revision-support policy, and `ROADMAP.md` schedules no removal (whether 2.0.0 drops them "depends on how future MCP spec revisions treat these features and on adoption of their replacements") | Target the gem's actual version, not the spec's. `initialize`/sessions/server-initiated requests are current API here |
| `require "mcp/transports"` fails | `MCP::Transports` module **removed in 0.15.0** | Use `MCP::Server::Transports::StdioTransport` / `StreamableHTTPTransport` |
| `Server#notify_progress` / `#create_sampling_message` undefined | Broadcast progress API removed 0.10.0; direct `create_sampling_message` removed 0.13.0 | Use the per-connection `server_context` helpers (see [server-dsl.md](server-dsl.md#server-side-advanced-server_context)) |
| HTTP request rejected as too large, or stdio memory grows unbounded | DoS hardening added in 0.23.0: bounded request body, bounded stdio line reads (`max_line_bytes`, default 4 MiB), bounded session retention | Tune `max_request_bytes:` / `max_line_bytes:` if you legitimately need larger payloads |
| Cross-origin or wrong-Host requests rejected | DNS-rebinding protection (Host/Origin validation) is on by default since 0.23.0 | Whitelist via `allowed_hosts:` / `allowed_origins:` on `StreamableHTTPTransport` |
| `SyntaxError` on Ruby 2.7.0 | Argument-forwarding syntax bug, fixed in 0.22.0 | Upgrade to ≥ 0.22.0 |
| Looking for the MRTR retry to happen automatically | `MCP::Client::InputRequiredError` only *surfaces* the `input_required` result — the source states plainly: "This SDK does not yet drive that resume loop automatically; callers can inspect `input_requests` and respond manually" | Rescue it, fulfil `input_requests` yourself, and re-issue the original request with `inputResponses` + the echoed `request_state` under a **new** id |
| `on_elicitation` / `on_sampling` raise `ArgumentError: The transport does not support server-to-client requests` | Both delegate to `transport.on_server_request`, which only exists on transports implementing the *legacy* server-initiated request mechanism | Use a transport that supports it (stdio, or HTTP with sessions). There is no modern-era equivalent in the gem — modern servers deliver these via MRTR instead |

## Maturity signals

- **Version 1.0.0 (2026-07-24) — out of pre-1.0.** The public API is stable, breaking changes ship in
  majors, subject to the spec-conformance / security / clear-defect exceptions in `VERSIONING.md`. The
  older advice to pin-and-read-the-CHANGELOG-every-bump no longer applies the same way; the historical
  churn (module removals in 0.10.0/0.13.0/0.15.0, the 0.23.0 handshake change) is behind the 1.0 line.
- **Roadmap target: SEP-1730 Tier 1.** `ROADMAP.md` states the SDK "implements the 2025-06-18 and
  2025-11-25 spec revisions, and passes all server and client conformance scenarios," maintaining a
  **100% conformance pass rate** as scenarios are added.
- **Explicit non-goal:** the legacy 2024-11-05 SSE transport is "intentionally out of scope; the SDK
  provides modern Streamable HTTP only."
- **Deprecation posture:** Roots/Sampling/Logging remain fully supported throughout 1.x; runtime
  warnings are planned for a future minor; removal would need a major and **is not scheduled**.
- **Very active:** ~25 minor releases plus 1.0.0 in ~15 months, roughly weekly/biweekly cadence.
- **Official and backed:** the official MCP-org SDK, built with Shopify; ships a conformance test suite
  (since 0.8.0) and tracks protocol SEPs closely — often implementing them while still in PR.
- Documentation now has a dedicated site: `https://ruby.sdk.modelcontextprotocol.io`, and
  `examples/rails` ships in the repo (the long-standing Rails-example request, **issue #44, is closed**).

## Sources (fetched 2026-07-29, `main`, gem v1.0.0)

- https://rubygems.org/api/v1/gems/mcp.json and `/api/v1/versions/mcp.json` (1.0.0, released 2026-07-24)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/CHANGELOG.md
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/ROADMAP.md (era-gap statement, SEP-1730 Tier 1, conformance, deprecation posture)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/VERSIONING.md (SemVer + conformance/security/defect exceptions)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/configuration.rb (protocol-version constants — still `2025-11-25`)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/server.rb (`server/discover`, `ttl_ms`/`cache_scope`)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/server_context.rb (`@deprecated` doc tags — no runtime warnings)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client.rb (`InputRequiredError`, `on_sampling`/`on_elicitation`)
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/README.md (Rails mount + controller patterns)
- https://api.github.com/repos/modelcontextprotocol/ruby-sdk/contents/examples (confirms `examples/rails`) and `/issues/44` (confirms closed)
- https://ruby.sdk.modelcontextprotocol.io (documentation site, linked from the gemspec)

If re-verifying against a newer release: read `ROADMAP.md` **first** — the single most important thing
to check is whether `SUPPORTED_STABLE_PROTOCOL_VERSIONS` in `configuration.rb` has gained
`2026-07-28`, because that (or a 2.0.0 release) is what closes the era gap and invalidates the framing
throughout this skill.
