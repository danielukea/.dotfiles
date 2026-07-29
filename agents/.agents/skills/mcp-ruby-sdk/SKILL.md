---
name: mcp-ruby-sdk
description: Deep API reference for the official Ruby SDK (the `mcp` gem) for building MCP servers/clients in Ruby. Use when writing or reviewing an `MCP::Server`/`MCP::Client`, defining `MCP::Tool`/`Resource`/`Prompt`, wiring stdio or `StreamableHTTPTransport`, or configuring `MCP.configure`. Trigger on "mcp gem", "MCP::Server", "StreamableHTTPTransport", or "Mcp::" in Ruby. Concrete API only — for protocol concepts see `model-context-protocol` first.
---

# MCP Ruby SDK

Deep reference for the official Ruby SDK for MCP — gem **`mcp`**
([github.com/modelcontextprotocol/ruby-sdk](https://github.com/modelcontextprotocol/ruby-sdk)).
**This file is a router.** Full API surface (every constructor kwarg, every DSL style) lives in
`references/`; this page tells you which file to open and flags the traps worth knowing before you get
there. For *what a Tool/Resource primitive is* or *how the wire protocol works*, start with
`model-context-protocol` — this skill assumes that knowledge and only covers the Ruby API.

**Observed:** gem `mcp`, version **1.0.0** (released 2026-07-24), Apache-2.0, Ruby `>= 2.7.0`, sole
runtime dependency `json_schemer` (`faraday` + `event_stream_parser` only for the HTTP client
transport). Official MCP-org SDK, built in collaboration with Shopify, ships **both server and client**.
Docs now at [ruby.sdk.modelcontextprotocol.io](https://ruby.sdk.modelcontextprotocol.io).

**1.0.0 means the public API is stable** — breaking changes ship only in majors, with narrow documented
exceptions: the SDK treats **spec-conformance deviations, security fixes, and clear defects as bugs**
fixable in a minor even if you relied on the old behavior (`VERSIONING.md`). That's a meaningfully
different upgrade posture from the pre-1.0 advice to pin and read the CHANGELOG every time.

## ⚠️ The gem is one protocol era behind the spec

**Read this before reasoning about anything else here.** `model-context-protocol` documents
`2026-07-28`, which is **stateless** — no `initialize`, no sessions, no server-initiated requests. The
gem does not implement that yet:

- `Configuration::LATEST_STABLE_PROTOCOL_VERSION` is **`"2025-11-25"`**, and
  `SUPPORTED_STABLE_PROTOCOL_VERSIONS` does **not** include `2026-07-28`.
- `ROADMAP.md` is explicit: additive `2026-07-28` features ship **opt-in during 1.x**, while "breaking
  parts of that revision, such as the SEP-2575 stateless lifecycle rewrite, are **reserved for 2.0**."
- So the gem is a **Legacy-era (handshake + sessions) implementation that has cherry-picked additive
  modern features**: `server/discover`, MRTR `input_required` recognition, `ttlMs`/`cacheScope`,
  capability `extensions`, and the `Mcp-Method`/`Mcp-Name` headers.

Practical upshot: `initialize`, `Mcp-Session-Id`, `resources/subscribe`, and server-initiated
`sampling/createMessage` are all still **the correct, current way to use this gem** — even though the
spec removed them. Don't "fix" working 1.x code to match the spec, and don't tell a user their gem is
broken because it speaks `2025-11-25`.

## Surface → Reference

The `Need` column is your "when to reach for this" index; each row routes to the file with the full treatment.


| Need | Reach for | Reference |
| --- | --- | --- |
| Stand up a server, register tools/resources/prompts | `MCP::Server.new` | [server-dsl.md](references/server-dsl.md#defining-a-server) |
| Define a Tool (class-based / block / server-level) | `MCP::Tool` / `Tool.define` / `server.define_tool` | [server-dsl.md](references/server-dsl.md#defining-tools) |
| Define a Resource or a parameterized resource | `MCP::Resource` / `MCP::ResourceTemplate` (class-based now supported) | [server-dsl.md](references/server-dsl.md#defining-resources) |
| Define a Prompt | `MCP::Prompt` / `Prompt.define` / `server.define_prompt` | [server-dsl.md](references/server-dsl.md#defining-prompts) |
| Global config, error reporting, request instrumentation | `MCP.configure` | [server-dsl.md](references/server-dsl.md#configuration--instrumentation) |
| Emit cache hints on list/read results | `ttl_ms:` / `cache_scope:` (**opt-in**) | [server-dsl.md](references/server-dsl.md#cache-hints-ttl_ms--cache_scope) |
| Answer a sessionless capability probe | `server/discover` handler | [server-dsl.md](references/server-dsl.md#serverdiscover) |
| Server-side sampling / roots / progress / elicitation calls | `server_context.*` | [server-dsl.md](references/server-dsl.md#server-side-advanced-server_context) |
| Cooperative cancellation / progress on a long-running tool | `MCP::Progress#report`, `MCP::Cancellation`, `MCP::CancelledError` | [server-dsl.md](references/server-dsl.md#progress-cancellation-and-tracing) |
| Propagate an OpenTelemetry trace across an MCP call | `MCP::TraceContext::META_KEYS` (`_meta`) | [server-dsl.md](references/server-dsl.md#distributed-tracing-_meta-mcptracecontext) |
| Wire prompt-argument / resource-template autocomplete | `server.completion_handler` | [server-dsl.md](references/server-dsl.md#completion) |
| Connect to a server from Ruby | `MCP::Client` + `Client::Stdio` / `Client::HTTP` | [client-and-transports.md](references/client-and-transports.md#mcpclient) |
| Handle a server asking the client for input | `on_elicitation` / `on_sampling`; `Client::InputRequiredError` | [client-and-transports.md](references/client-and-transports.md#client-side-server-request-handlers) |
| Deploy over HTTP — Rails/Sinatra mounting, sessions, DNS-rebinding config | `MCP::Server::Transports::StreamableHTTPTransport` | [client-and-transports.md](references/client-and-transports.md#streamablehttptransport) |
| OAuth 2.1 client flow (PKCE, CIMD, `private_key_jwt`, ID-JAG) | `MCP::Client::OAuth::Provider` | [client-and-transports.md](references/client-and-transports.md#oauth) |
| Run `MCP::Client` inside a multi-process/multi-threaded web server | pooling, per-tenant token storage, thread-safety | [client-in-web-server.md](references/client-in-web-server.md) |
| Test a server built with this gem | `server.handle` / `server.handle_json` | [testing-and-gotchas.md](references/testing-and-gotchas.md#testing) |
| "Why is my tool arg nil / this method gone" / which spec versions work | version history, removed APIs, `symbolize_names` | [testing-and-gotchas.md](references/testing-and-gotchas.md#gotchas) |

## Gotchas (hooks — full detail in references)

- **The gem negotiates `2025-11-25`, not `2026-07-28`** — see the era-gap section above. This is the
  single most likely source of confusion when reading this skill alongside `model-context-protocol`.
- **`stateless: true` is a deployment escape hatch, not SEP-2575 statelessness.** It suppresses session
  issuance so you can run multi-process without sticky sessions; it does *not* make the gem speak the
  modern per-request protocol, and it costs you notifications and server→client requests.
- **The SDK does not drive the MRTR resume loop.** It recognizes `input_required` and raises
  `MCP::Client::InputRequiredError` exposing `input_requests`/`request_state` — **you** re-issue the
  request manually. Nothing automatic here yet.
- **Roots/Sampling/Logging deprecations are YARD `@deprecated` doc tags only — they emit no runtime
  warning.** `ROADMAP.md` says warnings arrive "in a future minor release," and 1.x keeps all three
  fully supported. Don't promise a user a warning they won't see, and don't claim their code is
  emitting one.
- **`ttlMs`/`cacheScope` emission is opt-in and off by default** — with both `nil`, results serialize
  exactly as before. The spec *requires* these fields; the gem doesn't send them unless you configure
  it, and `server/discover` doesn't include them at all yet.
- Tool handler gets `nil` for `payload["key"]` even though data is present — transports parse args with
  **`symbolize_names: true`** at every nesting level; use `payload[:key]`, and round-trip through
  `JSON.generate`/`JSON.parse(..., symbolize_names: true)` in unit tests to match.
- stdio client requests hang or error "not connected" — since **0.23.0** `MCP::Client#connect` is
  required before sending any request; implicit init is gone.
- `require "mcp/transports"` raises `LoadError` — `MCP::Transports` was **removed in 0.15.0**; use
  `MCP::Server::Transports::StdioTransport` / `StreamableHTTPTransport`.
- Sessions/notifications randomly break in production — `StreamableHTTPTransport` holds session + SSE
  state **in memory, single-process only**; run `workers 0`, use sticky sessions, or pass
  `stateless: true`.
- `Server#notify_progress` / `#create_sampling_message` is undefined — both removed (0.10.0 / 0.13.0);
  use the per-connection `server_context` helpers.
- One user occasionally sees another user's MCP data — a single `MCP::Client::HTTP` was shared or
  memoized across requests; its session ID and OAuth bearer token are **instance state**, not per-call.
- `on_elicitation`/`on_sampling` raise `ArgumentError` — they require a transport that supports
  `on_server_request`, i.e. the *legacy* server-initiated mechanism. There is no modern-era equivalent
  in the gem.
- `SyntaxError` on Ruby 2.7.0 — argument-forwarding bug fixed in 0.22.0; upgrade.

## Bundled References

- **[references/server-dsl.md](references/server-dsl.md)** — module map, `MCP::Server.new` (incl.
  `ttl_ms`/`cache_scope`), a minimal server, all three Tool styles + `InputSchema`/`OutputSchema`/
  `Tool::Response`, Resource/ResourceTemplate (class-based and instance), Prompt + Content classes,
  `MCP.configure`, `server/discover`, MCP Apps helpers, `server_context` helpers, `MCP::Progress`/
  `Cancellation`, `MCP::TraceContext`, `completion_handler`.
- **[references/client-and-transports.md](references/client-and-transports.md)** — the `MCP::Client`
  API, `Client::Stdio`/`Client::HTTP` and `StreamableHTTPTransport`/`OAuth::Provider` constructors,
  client-side server-request handlers and `InputRequiredError`, and Rails/Sinatra Rack-mounting.
- **[references/client-in-web-server.md](references/client-in-web-server.md)** — why
  `MCP::Client::HTTP` can't be shared across threads, the pool-per-tenant-per-server pattern, the OAuth
  token-storage seam, and resilience patterns for calling a third-party server from a request-serving
  fleet.
- **[references/testing-and-gotchas.md](references/testing-and-gotchas.md)** — the in-process
  `server.handle`/`handle_json` testing pattern, the `symbolize_names` round-trip gotcha, the
  protocol-version/era-compatibility picture, release history since 0.23.0, and every gotcha above with
  CHANGELOG/issue citations.

---

*Sources: [github.com/modelcontextprotocol/ruby-sdk](https://github.com/modelcontextprotocol/ruby-sdk),
`main` branch, observed at gem version 1.0.0, fetched directly (raw source files, RubyGems API, and the
GitHub API — not reconstructed from training memory) in July 2026. Each reference file carries its own
exact source URLs, plus the commit context needed to re-verify against a newer gem release.*
