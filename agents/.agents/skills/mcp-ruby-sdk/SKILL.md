---
name: mcp-ruby-sdk
description: Deep API reference for the official Ruby SDK (the `mcp` gem) for building MCP servers/clients in Ruby. Use when writing or reviewing an `MCP::Server`/`MCP::Client`, defining `MCP::Tool`/`Resource`/`Prompt`, wiring stdio or `StreamableHTTPTransport`, or configuring `MCP.configure`. Trigger on "mcp gem", "MCP::Server", "StreamableHTTPTransport", or "Mcp::" in Ruby. Concrete API only — for protocol concepts see `model-context-protocol` first.
---

# MCP Ruby SDK

Deep reference for the official Ruby SDK for MCP — gem **`mcp`**
([github.com/modelcontextprotocol/ruby-sdk](https://github.com/modelcontextprotocol/ruby-sdk)).
**This file is a router.** Full API surface (every constructor kwarg, every DSL style) lives in
`references/`; this page tells you which file to open and flags the traps worth knowing before you
get there. For *what a Tool/Resource/Sampling primitive is* or *how the wire protocol works*, start
with `model-context-protocol` — this skill assumes that knowledge and only covers the Ruby API.

**Observed:** gem `mcp`, version **0.23.0**, Apache-2.0, Ruby `>= 2.7.0`, sole runtime dependency
`json_schemer` (`faraday` + `event_stream_parser` needed only for the HTTP client transport).
Official MCP-org SDK, built in collaboration with Shopify, ships **both server and client**. Still
**pre-1.0** — active development (~23 minor releases in ~14 months) with real breaking changes
across minor versions (module removals, a 0.23.0 handshake behavior change). **Pin the version and
read the CHANGELOG before upgrading.**

## Surface → Reference

The `Need` column is your "when to reach for this" index; each row routes to the file with the full treatment.


| Need | Reach for | Reference |
| --- | --- | --- |
| Stand up a server, register tools/resources/prompts | `MCP::Server.new` | [server-dsl.md](references/server-dsl.md#defining-a-server) |
| Define a Tool (class-based / block / server-level) | `MCP::Tool` / `Tool.define` / `server.define_tool` | [server-dsl.md](references/server-dsl.md#defining-tools) |
| Define a Resource or a parameterized resource | `MCP::Resource` / `MCP::ResourceTemplate` | [server-dsl.md](references/server-dsl.md#defining-resources) |
| Define a Prompt | `MCP::Prompt` / `Prompt.define` / `server.define_prompt` | [server-dsl.md](references/server-dsl.md#defining-prompts) |
| Global config, error reporting, request instrumentation | `MCP.configure` | [server-dsl.md](references/server-dsl.md#configuration--instrumentation) |
| Server-side sampling / roots / progress / elicitation calls | `server_context.*` | [server-dsl.md](references/server-dsl.md#server-side-advanced-server_context) |
| Cooperative cancellation / progress reporting on a long-running tool | `MCP::Progress#report`, `MCP::Cancellation`, `MCP::CancelledError` | [server-dsl.md](references/server-dsl.md#progress-cancellation-and-tracing) |
| Propagate an OpenTelemetry trace across an MCP call | `MCP::TraceContext::META_KEYS` (`_meta`) | [server-dsl.md](references/server-dsl.md#distributed-tracing-_meta-mcptracecontext) |
| Wire prompt-argument / resource-template autocomplete | `server.completion_handler` | [server-dsl.md](references/server-dsl.md#completion) |
| Connect to a server from Ruby | `MCP::Client` + `Client::Stdio` / `Client::HTTP` | [client-and-transports.md](references/client-and-transports.md#mcpclient) |
| Deploy over HTTP — Rails/Sinatra mounting, sessions, DNS-rebinding config | `MCP::Server::Transports::StreamableHTTPTransport` | [client-and-transports.md](references/client-and-transports.md#streamablehttptransport) |
| OAuth 2.1 client flow (PKCE, CIMD) | `MCP::Client::OAuth::Provider` | [client-and-transports.md](references/client-and-transports.md#oauth) |
| Run `MCP::Client` inside a multi-process/multi-threaded web server, not a CLI | pooling, per-tenant token storage, thread-safety | [client-in-web-server.md](references/client-in-web-server.md) |
| Test a server built with this gem | `server.handle` / `server.handle_json` | [testing-and-gotchas.md](references/testing-and-gotchas.md#testing) |
| "Why is my tool arg nil / this method gone" | version history, removed APIs, `symbolize_names` | [testing-and-gotchas.md](references/testing-and-gotchas.md#gotchas) |

## Gotchas (hooks — full detail in references)

| Symptom | Real cause |
| --- | --- |
| Tool handler gets `nil` for `payload["key"]` even though data is present | Transports parse args with **`symbolize_names: true`** at every nesting level — use `payload[:key]`; round-trip through `JSON.generate`/`JSON.parse(..., symbolize_names: true)` in unit tests to match |
| stdio client requests hang or error "not connected" | As of **0.23.0**, `MCP::Client#connect` is required before sending any request — implicit init is gone |
| `require "mcp/transports"` raises `LoadError` | `MCP::Transports` module was **removed in 0.15.0** — use `MCP::Server::Transports::StdioTransport` / `StreamableHTTPTransport` |
| Sessions/notifications randomly break in production | `StreamableHTTPTransport` holds session + SSE state **in memory, single-process only** — run `workers 0`, use sticky sessions, or pass `stateless: true` |
| `Server#notify_progress` / `#create_sampling_message` is undefined | Both removed (0.10.0 / 0.13.0) — use the per-connection `server_context` helpers instead |
| Roots/Sampling/Logging `server_context` helpers emit deprecation warnings | The **SDK itself** (0.23.0) annotates these per SEP-2577, ahead of a not-yet-published spec revision it cites as `2026-07-28`. This is the SDK's own forward-looking choice — the current published protocol spec (`2025-11-25`) still has Logging as fully active, not deprecated (see `model-context-protocol`) |
| No Rails example in the repo | Known doc gap (issue #44) — the transport **is a Rack app**; `mount transport => "/mcp"` works directly |
| `SyntaxError` on Ruby 2.7.0 | Argument-forwarding syntax bug, fixed in 0.22.0 — upgrade |
| One user occasionally sees another user's MCP data | A single `MCP::Client::HTTP` was shared/memoized across requests — its session ID and OAuth bearer token are instance state, not per-call (see [client-in-web-server.md](references/client-in-web-server.md)) |

## Bundled References

- **[references/server-dsl.md](references/server-dsl.md)** — module map, `MCP::Server.new`, a minimal server, all three Tool styles + `InputSchema`/`OutputSchema`/`Tool::Response`, Resource/ResourceTemplate, Prompt + Content classes, `MCP.configure`, `server_context` helpers, `MCP::Progress`/`Cancellation`, `MCP::TraceContext`, `completion_handler`.
- **[references/client-and-transports.md](references/client-and-transports.md)** — the `MCP::Client` API, verified `Client::Stdio`/`Client::HTTP` and `StreamableHTTPTransport`/`OAuth::Provider` constructors, and Rails/Sinatra Rack-mounting.
- **[references/client-in-web-server.md](references/client-in-web-server.md)** — why `MCP::Client::HTTP` can't be shared across threads, the pool-per-tenant-per-server pattern, the OAuth token-storage seam, and resilience patterns for calling a third-party server from a request-serving fleet.
- **[references/testing-and-gotchas.md](references/testing-and-gotchas.md)** — the in-process `server.handle`/`handle_json` testing pattern, the `symbolize_names` round-trip gotcha, protocol-version compatibility, and every gotcha above with CHANGELOG/issue citations.

---

*Sources: [github.com/modelcontextprotocol/ruby-sdk](https://github.com/modelcontextprotocol/ruby-sdk), `main` branch, observed at gem version 0.23.0, fetched directly (raw source files, not reconstructed from training memory) in July 2026. Each reference file below carries its own exact source URLs, plus the commit context needed to re-verify against a newer gem release.*
