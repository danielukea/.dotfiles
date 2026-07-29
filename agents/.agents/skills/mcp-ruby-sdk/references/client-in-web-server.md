# Using `MCP::Client` from a Web Server (not a CLI/Desktop Process)

Almost every MCP client tutorial — including this SDK's own README and `docs/building-clients.md`
— assumes a persistent local process (a CLI tool, a desktop app) that opens one client and keeps it
alive for the process's lifetime. That model doesn't transfer to a client embedded inside a
multi-process, multi-threaded web server (Puma-style) serving many concurrent, short-lived
requests — often for many different tenants, each with their own downstream MCP server connection.
**Neither the MCP spec nor this SDK's docs say anything about that deployment shape.** What follows
is either verified directly from the client's source (marked as such) or a recommended pattern by
analogy to well-established prior art for the same structural problem elsewhere in the Ruby
ecosystem (DB/Redis connection pooling, gRPC channel reuse, OAuth-refresh concurrency) — clearly
marked as such, not documented MCP guidance.

## The core rule: the session ID is data; the client object is not shareable

**Verified from source (`lib/mcp/client.rb`, `lib/mcp/client/http.rb`):** `MCP::Client` itself holds
no shared mutable state beyond `@transport` — thread-safety is entirely determined by the
transport. `MCP::Client::HTTP` is **not safe to share** across threads or requests, for two
independent, code-verified reasons:

1. **It's stateful per instance, and that state includes per-user identity.** `connect` mutates
   `@server_info`/`@connected`; every subsequent request reads `@session_id` and — critically —
   bakes the *current* OAuth bearer token into `session_headers`. A shared instance doesn't just
   race, it stamps **one session and one user's token onto every request** that happens to use it —
   a tenant-bleed hazard, not merely a data race.
2. **There is no synchronization anywhere in the HTTP transport.** `@client ||= Faraday.new(...)`
   and `@session_id ||= session_id` are non-atomic memoizations; `clear_session` (fired on a 404 or
   failed handshake) resets state a concurrent in-flight request on another thread may be depending
   on. (Contrast: the *stdio* transport does guard writes with a `Mutex` — but stdio spawns a local
   subprocess, so it isn't the relevant transport for a remote, multi-tenant client anyway.)

The session ID is exposed only via `attr_reader :session_id` — there's no public setter, so
rehydrating a transport onto an *existing* server-side session isn't supported without reaching for
`instance_variable_set`.

**The distinction that resolves all of the above:** the `Mcp-Session-Id` is just a string on an HTTP
header — data you're free to persist or pass around. The `MCP::Client`/transport *object* wraps a
live connection plus that mutable, per-user state — it is not.

## Recommended pattern: pool client objects, never share one

- Build one `MCP::Client` + transport per **(tenant, downstream server)**, checked out per request
  or background job — never memoize a shared instance in a class variable or constant.
- Use a fixed-size pool (Ruby's `connection_pool` gem is the standard tool for exactly this — the
  same model Rails uses for its own DB connection pool) sized to your web server's
  threads-per-process, so checkouts never internally contend. This is a recommendation by analogy
  to DB-pool / gRPC-channel-reuse prior art, not something the MCP SDK documents or provides itself
  — it ships no pooling and no `connection_pool` integration; you own the adapter choice.
- If you want warm-session reuse across requests, persist the *session ID string* (and OAuth
  tokens — see below) in your app's shared store, and rehydrate a pooled client with it. But treat
  any reused session as an optimization that must tolerate the server returning **404** (session
  terminated) and transparently re-`initialize` — never as a guarantee. The gem surfaces this as
  `MCP::Client::SessionExpiredError`, so it's straightforward to rescue.

  **That advice is now also your migration path.** SEP-2575 ("Make MCP Stateless") and SEP-2567
  ("Sessionless via explicit state handles") **shipped** in the `2026-07-28` spec, which removes the
  handshake and `Mcp-Session-Id` entirely. The gem hasn't followed yet — sessions are still how 1.x
  works, and the stateless rewrite is
  [reserved for 2.0](testing-and-gotchas.md#version--spec-compatibility--the-era-gap) — so everything
  in this file remains correct for 1.x. A 404-tolerant, never-memoized design is exactly what makes the
  2.0 upgrade uneventful: when sessions disappear, the session-rehydration step simply becomes
  unnecessary rather than wrong.

  One forward-looking caution: in the modern protocol, cross-request state moves to **server-minted
  handles passed as ordinary tool arguments** — and possession of a handle is *not* authentication.
  If you start using such handles against a modern server, bind them to the authenticated user
  server-side; see **state handle hijacking** in
  [security.md](../../model-context-protocol/references/security.md#named-attack-patterns).

## OAuth: token storage is a clean seam; the interactive flow is not

**Verified from source** (`lib/mcp/client/oauth/storage_backed_provider.rb`,
`in_memory_storage.rb`, `provider.rb`): the SDK exposes a duck-typed, 4-method storage interface —
`tokens`, `save_tokens(tokens)` (passing `nil` clears them), `client_information`,
`save_client_information(info)` — injected via `Provider.new(storage:)` (default `InMemoryStorage`,
which loses everything on process exit and is unusable across a multi-process web server).

- **Recommended:** implement that interface backed by an encrypted, per-tenant DB column, keyed at
  minimum by *which* downstream server it's for (a tenant may talk to more than one). This matches
  the shape other MCP client SDKs use for the same problem — e.g. Python's FastMCP keys its token
  storage by server URL too — which is corroborating cross-SDK evidence this is the right shape to
  reach for, not a Ruby-SDK peculiarity.
- **Refresh and initial authorization are different in kind — don't collapse them.** Verified from
  source: refreshing an expired access token via a saved `refresh_token` is a normal, non-interactive
  HTTP exchange, and it's safe to let happen inline (subject to the single-flight note below). The
  *initial* interactive authorization-code grant is not the same shape: the SDK's `Provider`/`Flow`
  drives it **synchronously**, via blocking `redirect_handler`/`callback_handler` callables invoked
  from inside `send_request` — a shape that assumes a process that can pause and wait for a browser
  redirect to come back. That doesn't exist inside a single web request/response cycle. Do the
  redirect/callback dance in your own ordinary OAuth controller flow, persist the resulting tokens
  into your storage implementation, and use the SDK's provider only for storage + refresh — not for
  driving the interactive grant itself.
- **Thundering herd on refresh (a general OAuth-under-concurrency problem, not MCP-specific):** if
  several concurrent requests for the same tenant all see an expired token, each will try to refresh
  independently; combined with refresh-token rotation, that can make all-but-one look like token
  theft. Serialize refresh behind a single-flight lock keyed by `(tenant, server)` in your shared
  store (e.g. a short-lived Redis lock) so exactly one refresh runs and the rest wait and reuse its
  result. The SDK provides no locking of its own here — this is on you.

## Where to actually make the call: inline vs. background

- **Inline in the request:** simplest, but ties up one of your server's request-handling threads
  for the full round trip to a server you don't control. Only reasonable with hard, short timeouts.
- **Offload to your background-job system, then push or poll the result back:** the safer default
  for anything not reliably fast — it keeps a slow or down downstream MCP server from starving
  unrelated requests. If the call is genuinely long-running, MCP's **Tasks** extension
  (a pollable task handle returned from `tools/call` — see `model-context-protocol`'s
  [primitives.md](../../model-context-protocol/references/primitives.md#tasks--now-an-extension-not-a-primitive)) is a
  natural fit for a background job to hold and poll instead of a request thread blocking on it.
  **This pairing (Tasks + background-job offload) is a design suggestion, not documented MCP or SDK
  guidance** — nothing in the sources connects them explicitly.

## Resilience — protect your thread pool from someone else's server

- Set explicit, short connect/read timeouts on the transport's underlying Faraday connection —
  without them, one hung downstream server can pin a request-handling thread indefinitely.
- Keep retries few and limited to safe/idempotent operations — a naive "5 retries × 10s timeout" can
  hold a thread for the sum of all of them, which is worse than not retrying under load.
- Consider a circuit breaker per downstream MCP server so a failing one fails fast instead of
  queueing doomed requests; if you run multiple processes, its state store needs to be shared across
  them — a per-process in-memory breaker doesn't protect the fleet as a whole.
- Give MCP calls their own bounded resource (a dedicated pool, ideally a dedicated background-job
  queue) so one misbehaving downstream server can't exhaust resources shared with unrelated app
  functionality.

## Gotchas

| Symptom | Real cause |
| --- | --- |
| One user occasionally gets another user's data back from an MCP tool call | A single `MCP::Client::HTTP` instance was shared/memoized and reused across requests — its session ID and bearer token are instance state, not per-call |
| Session/auth state randomly resets mid-traffic | `clear_session` fired (on a 404 or failed handshake) on an instance another thread was concurrently using — the transport has no mutex protecting this |
| OAuth "login" flow hangs a web request forever | The SDK's interactive authorization-code grant blocks synchronously on `redirect_handler`/`callback_handler` callables — it assumes a pausable process, not a request/response cycle. Hand-roll the redirect/callback in your own controller instead |
| Some users get logged out / re-prompted for auth under load | Concurrent requests raced a token refresh; with refresh-token rotation, losing the race can look like token theft. Serialize refreshes with a per-`(tenant, server)` lock |
| A single slow or down MCP server stalls unrelated requests | No timeout/circuit-breaker/bulkhead around the outbound call — it's sharing the same thread pool and no resource isolation exists |

## Sources

Code-verified claims (session/thread-safety, OAuth storage interface, refresh vs. interactive-flow
distinction) — fetched 2026-07-09, `main` branch, gem v0.23.0:
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client/http.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client/stdio.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client/oauth/storage_backed_provider.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client/oauth/in_memory_storage.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/lib/mcp/client/oauth/provider.rb
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/docs/building-clients.md
- https://raw.githubusercontent.com/modelcontextprotocol/ruby-sdk/main/README.md

Analogous prior-art sources for the recommended (non-MCP-specific) patterns above:
- https://oneuptime.com/blog/post/2026-03-31-redis-connection-pooling-ruby/view — `connection_pool` gem model, pool sizing per web-server process
- https://blog.arkency.com/rails-connections-pools-and-handlers/ — Rails connection pool internals
- https://mchesnavsky.tech/grpc-channel-stub-reuse/ and https://grpc.io/docs/guides/performance/ — channel/stub reuse as the closest structural analog
- https://deepwiki.com/jlowin/fastmcp/7.4-token-storage-and-management — cross-SDK confirmation of a pluggable, server-URL-keyed token storage pattern
- https://nango.dev/blog/concurrency-with-oauth-token-refreshes/ and https://mojoauth.com/blog/thundering-herd-distributed-auth-caching — single-flight lock pattern for OAuth refresh under concurrency
- https://mattbrictson.com/blog/advanced-http-techniques-in-ruby — Faraday timeouts/retries; https://github.com/lostisland/faraday-retry
- https://www.rubydoc.info/gems/circuitbox/1.0.1 — circuit breaker, per-process vs. shared cache store caveat under a multi-process server

If re-verifying: this whole file is a documentation-gap synthesis, not a spec/SDK citation — the
"code-verified" sources above are the load-bearing ones to re-check first if the gem's client or
OAuth internals change.
