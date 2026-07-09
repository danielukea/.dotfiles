# Caching in MCP

**Headline answer, since it's the sharpest finding here: yes, cached tool/resource lists need to be
scoped, and it's more specific than "by tenant."** The scoping unit the spec reaches for is
**authorization context** (effectively, the access token) — a cached response that contains
user-specific data must never be served to a different token, full stop. Read on for exactly where
that rule currently lives and what's released vs. proposed.

**Claim tiering — carried through every section below, because this topic is unusually split
between shipped and proposed:**
- **RELEASED** — in the current `2025-11-25` core spec, citable as fact today.
- **DRAFT** — lives only under `/specification/draft/...` (unreleased). Real, specific, and
  well-designed, but **do not present as something a `2025-11-25` client can rely on today.**
- **COMMUNITY** — what MCP gateway/proxy implementations converged on before (and independent of)
  the draft spec.
- **INFERENCE** — a reasoned extrapolation this skill is making, explicitly **not** endorsed by the
  spec — treat with the most skepticism.

## RELEASED today: no caching semantics exist yet

- Tool annotations (`readOnlyHint`/`destructiveHint`/`idempotentHint`/`openWorldHint`, see
  [primitives.md](primitives.md#tools)) exist, but the spec's own framing for them is confirmation-
  prompt UX and trust/policy decisions — **not caching**. The dedicated tool-annotations writeup is
  explicit that these are unverified hints a malicious server can lie about, and that clients
  "should never make tool use decisions based on ToolAnnotations received from untrusted servers."
  Do not treat `readOnlyHint`/`idempotentHint` as a spec-sanctioned caching signal.
- `notifications/{tools,resources,prompts}/list_changed` exist (see
  [primitives.md](primitives.md)), but the released spec gives no guidance on caching around them —
  client-side list caching today is entirely implementation-defined.
- `resources/subscribe` + `notifications/resources/updated` is **push-invalidation**, not a
  conditional-GET mechanism — subscribing gets you a "this changed, re-read" push, not a
  cache-validation exchange.
- A resource's `lastModified` annotation is **display-only** (sorting/UI), not a cache validator —
  there is no ETag / If-Modified-Since equivalent anywhere in MCP today.
- Streamable HTTP carries no HTTP-level caching semantics — no `Cache-Control`, no `ETag`, nothing.
  Every JSON-RPC message is its own POST with a JSON-RPC-shaped body, so ordinary HTTP response
  caching doesn't apply. This is a deliberate design gap the draft spec below fills at the
  application layer instead of trying to reuse HTTP caching headers.

## DRAFT (unreleased): the `ttlMs` + `cacheScope` model

Source: the draft `Caching` utility page (`/specification/draft/server/utilities/caching`) —
**not part of `2025-11-25`.** Verify it hasn't shipped (and check which version it shipped *in*)
before citing this as current.

**What's cacheable:** results with `resultType: "complete"` from `server/discover`, `tools/list`,
`prompts/list`, `resources/list`, `resources/templates/list`, and `resources/read`. Notably
**excluded**: `tools/call` and `prompts/get` — anything with side effects or per-invocation
semantics is out of scope for this mechanism entirely. Interim/multi-round-trip results (anything
carrying `inputResponses`/`requestState`) must not be cached either.

**`ttlMs`** — a freshness hint, explicitly analogous to HTTP `Cache-Control: max-age`. `0` means
immediately stale; absent means clients should assume `0` (treat that as "this server hasn't
adopted the field yet," not "cache forever"); negative is treated as `0`. It's a hint, not a
guarantee — the underlying data can change before it expires.

**`cacheScope` — this is the field that answers the scoping question:**

| Value | Meaning (draft spec, near-verbatim) |
| --- | --- |
| `"public"` | Response contains no user-specific data. Any client, shared gateway, or caching proxy MAY store and serve it to any user. Appropriate for tool/prompt/resource-template lists **when they're identical for everyone**. |
| `"private"` | Response contains data specific to the caller. MAY be reused for the *same* authorization context, but **MUST NOT be shared across authorization contexts** — a different access token requires a different cache entry. Appropriate for `resources/read` results, or for **filtered list results that vary per user**. |

The draft spec explicitly anticipates that a server can return different tools to different callers
of the "same" logical server (permission-scoped catalogs) — when that's true, cache by
authorization context, not by server identity alone. It also states the caveat plainly:
`cacheScope` is a caching hint, not access control — servers "MUST NOT rely on `cacheScope` alone
to prevent unauthorized access to primitives," and a `"public"`-scoped response can still end up
shared between callers even from an authenticated endpoint if the server mis-scoped it.

**Cache key (draft, verbatim intent):** the request method plus whatever parameters affect the
result — e.g. `uri` for `resources/read`, `cursor` for a paginated list. Clients must not serve a
cached response for a request whose method or result-affecting params differ. Note what's *not* in
that key: protocol version or negotiated capabilities. Including those defensively (an old and a
new client could see different tool shapes from the same server) is a reasonable thing to do, but
it's **INFERENCE** on top of the draft text, not something the draft spec itself requires.

**Invalidation:** dual mechanism — a relevant `list_changed`/`resources/updated` notification
invalidates a still-fresh cache immediately, and TTL is the fallback for servers that don't send
notifications (or a client that missed one). The draft spec is explicit that TTL should **not** be
treated as a polling interval — don't build a background refetch loop off it; if you do poll for
some other reason, apply jitter and backoff.

**Pagination specifics (draft):** each page of a list is independently cacheable with its own
`ttlMs`, but every page of a given list request must share the same `cacheScope`. On an invalid or
expired cursor, discard everything cached for that list and restart pagination from the beginning
rather than trying to patch around it.

## COMMUNITY practice (gateways/proxies, largely predating the draft spec)

Real MCP gateway/proxy implementations converged on the same shape independently:
- Cache read-shaped operations (`*/list`, `resources/read`) freely; never cache `tools/call` at a
  generic client/gateway layer — side effects disqualify it.
- Build **composite** cache keys: method + params/URI + server version/identity + **auth context**
  — the same conclusion the draft spec's `cacheScope` reaches, arrived at independently, specifically
  to prevent cache poisoning across users or server versions.
- Layer TTLs by volatility: short for frequently-changing lists, much longer for near-static
  resources — paired with notification-based invalidation as the fast path and TTL as the safety
  net, never notifications alone (a server might not declare `listChanged`, or a notification might
  simply be missed).

**Caching tool-*call* results specifically — opt-in, narrow, and not generically inferred:** some
operators do cache the *result* of a `tools/call` for tools they've manually verified are genuinely
idempotent and side-effect-free, with a short TTL, at the server/gateway layer — never as a generic
client-side behavior. **This is the one place to be most careful about over-generalizing:** using
`readOnlyHint`/`idempotentHint` alone to decide this automatically is explicitly **not** what the
spec endorses (see the RELEASED section above), for three concrete reasons — (1) hints are
unverified and a server can misreport them, or drift out of sync as the tool's implementation
changes, (2) a truly read-only tool can still return fast-changing data, so "read-only" doesn't
imply "cacheable for any useful duration," and (3) caching keyed only on tool name + arguments,
without also scoping by auth context, reproduces the exact cross-tenant leak the `cacheScope`
`private` rule exists to prevent. Treat tool-call-result caching as a deliberate, per-tool,
per-auth-context, operator-verified decision — never a default a generic client infers from
annotations.

## Sources (exact URLs fetched, July 2026)

- https://modelcontextprotocol.io/specification/2025-11-25/server/tools
- https://modelcontextprotocol.io/specification/2025-11-25/server/resources
- https://modelcontextprotocol.io/specification/2025-11-25/basic/transports
- https://modelcontextprotocol.io/specification/2025-11-25/schema (verified `ToolAnnotations` field definitions directly against `schema.ts`)
- https://modelcontextprotocol.io/specification/draft/server/utilities/caching — **draft, unreleased**; re-check its status before citing
- https://raw.githubusercontent.com/modelcontextprotocol/modelcontextprotocol/main/docs/specification/draft/server/utilities/caching.mdx — raw source of the above, verbatim quotes taken from here
- https://blog.modelcontextprotocol.io/posts/2026-03-16-tool-annotations/ — "Tool Annotations as Risk Vocabulary," confirms annotations are not intended for caching decisions

Community-practice sources cited for pattern existence, not individually re-verified:
- https://www.gravitee.io/blog/mcp-api-gateway-explained-protocols-caching-and-remote-server-integration
- https://chatforest.com/guides/mcp-caching-strategies/

If re-verifying: the single most important thing to check is whether the draft caching page has
shipped into a released spec version — if it has, everything tagged **DRAFT** above should be
retagged **RELEASED (as of &lt;version&gt;)** and cited from `/specification/<that-date>/` instead
of `/specification/draft/`.
