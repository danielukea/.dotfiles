# Caching in MCP

**As of `2026-07-28`, caching is a released, mandatory part of the protocol** (SEP-2549). Servers
**MUST** attach `ttlMs` + `cacheScope` to cacheable results. If you remember MCP as having "no
caching semantics" — that was `2025-11-25` and earlier, where this lived only in a draft page.

**Headline answer, still the sharpest finding here: cached tool/resource lists must be scoped, and
the unit is finer than "per tenant."** It's the **authorization context** (effectively, the access
token). A cached response containing user-specific data must never be served to a different token.

## What's cacheable

Servers MUST include caching hints on `resultType: "complete"` results from exactly these:

`server/discover` · `tools/list` · `prompts/list` · `resources/list` ·
`resources/templates/list` · `resources/read`

**Not cacheable, deliberately:** `tools/call` and `prompts/get` — anything with side effects or
per-invocation semantics is out of scope for this mechanism. Neither are `resultType:
"input_required"` interim results, nor **any result produced by an MRTR retry** — a request carrying
`inputResponses` or `requestState` **MUST NOT** be cached, because it depends on inputs that aren't
part of the cache key (see [mrtr.md](mrtr.md)).

## Cache key

Request **method** + the request **parameters that affect the result** — e.g. `uri` for
`resources/read`, `cursor` for a paginated list. Clients **MUST NOT** serve a cached response for a
request whose method or result-affecting params differ.

Note what's *not* in that key: protocol version and negotiated capabilities. Including them
defensively is reasonable (an old and a new client can see different tool shapes from the same
server), but that's an **inference on top of the spec**, not something it requires.

## `ttlMs`

An integer, milliseconds, semantically HTTP `Cache-Control: max-age`. Servers **MUST** provide a
value `>= 0`.

| Value | Client behavior |
| --- | --- |
| positive | SHOULD treat fresh for that many ms after receipt |
| `0` | Immediately stale; MAY re-fetch on every access |
| absent | Assume `0` — "this server predates the field," **not** "cache forever." Should only happen with older servers |
| negative | Ignore it, treat as `0` |

Freshness is `now < t_received + ttlMs`.

**It's a freshness hint, not a guarantee** — the underlying data may change before expiry. TTL says
how long you can reasonably avoid re-fetching, not how long the data is stable.

Three rules that catch people:
- **Don't treat TTL as a polling interval.** Check freshness when you need the data; re-fetch only if
  stale. If you poll anyway, you **MUST** apply jitter and backoff.
- Clients **MAY** re-fetch early on evidence of change — e.g. a tool call failing with method-not-found
  or invalid-params suggests the cached list is wrong.
- Clients **MAY** serve stale data when re-fetching fails (network trouble, server down).

## `cacheScope` — the field that answers the scoping question

| Value | Meaning (near-verbatim) |
| --- | --- |
| `"public"` | No user-specific data. Any client, shared gateway, or caching proxy **MAY** store it and serve it to any user. Right for tool/prompt/resource-template lists **when identical for everyone**. |
| `"private"` | Contains caller-specific data. MAY be reused within the *same* authorization context, but caches **MUST NOT** be shared across authorization contexts — a different access token requires a different cache entry. Right for `resources/read` results that depend on the user, or per-user filtered lists. |

The spec anticipates permission-scoped catalogs — the same logical server returning different tools
to different callers. When that's true, cache by authorization context, not by server identity.

**`cacheScope` is a caching hint, not access control.** Servers **MUST** apply per-primitive access
controls and **MUST NOT** rely on `cacheScope` alone to prevent unauthorized access. And note the
sharp edge the spec calls out explicitly: a `"public"` result from an *authenticated* endpoint can
still legitimately be shared across access tokens by a conforming cache. Mis-scoping is a leak.

## Interaction with notifications

Complementary, not either/or:
- A server MAY send `ttlMs` **without** advertising `listChanged` — the client then relies purely on
  TTL.
- A server MAY do both — TTL avoids needless refetches between notifications, and the notification is
  an **immediate invalidation** signal for a still-fresh entry.

Don't rely on notifications alone: a server might not declare `listChanged`, or a notification might
be missed. TTL is the safety net. (Notification delivery now goes through `subscriptions/listen` —
see [request-model-and-transports.md](request-model-and-transports.md#subscriptionslisten).)

## Interaction with pagination

Each page is independently cacheable, with its own `ttlMs` clock starting when *that page* arrived.
Servers MAY vary `ttlMs` per page (longer for stable early pages, shorter for the last).

- **No cross-page consistency guarantee** — data changing mid-pagination can show you duplicates or
  gaps. Clients needing a consistent snapshot **SHOULD** re-fetch from the beginning, cursor-less.
- On an invalid/expired cursor, discard **all** cached pages for that list and restart from the
  beginning — don't patch around it.
- Servers **MUST** apply the **same `cacheScope` to every page** of a given list request. First page
  `"private"` ⇒ all pages `"private"`.

## Tool annotations are still not a caching signal

`readOnlyHint` / `destructiveHint` / `idempotentHint` / `openWorldHint` (see
[primitives.md](primitives.md#tools)) exist for confirmation-prompt UX and trust/policy decisions.
They are **unverified hints a malicious server can lie about**, and clients "should never make tool
use decisions based on ToolAnnotations received from untrusted servers."

Some operators *do* cache `tools/call` results for tools they've manually verified as idempotent and
side-effect-free, short TTL, at the server/gateway layer. That's a deliberate per-tool,
per-auth-context, operator-verified decision — never something a generic client infers from
annotations, for three concrete reasons: (1) hints are unverified and can drift out of sync with the
implementation, (2) a genuinely read-only tool can still return fast-changing data, so "read-only"
doesn't imply "cacheable for any useful duration," and (3) caching keyed only on tool name +
arguments, without auth-context scoping, reproduces exactly the cross-tenant leak the `"private"`
rule exists to prevent.

## Sources (exact URLs fetched, July 2026, `2026-07-28`)

- https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/caching — now RELEASED and mandatory; this page was `/specification/draft/...` as of the `2025-11-25` era
- https://modelcontextprotocol.io/specification/2026-07-28/changelog (SEP-2549 — `CacheableResult`, required `ttlMs`/`cacheScope`; deterministic `tools/list` ordering)
- https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/pagination
- https://modelcontextprotocol.io/specification/2026-07-28/server/tools (`ToolAnnotations` semantics)
- https://modelcontextprotocol.io/specification/2026-07-28/basic/patterns/mrtr (MRTR traffic is non-cacheable)
- https://blog.modelcontextprotocol.io/posts/2026-03-16-tool-annotations/ — "Tool Annotations as Risk Vocabulary," confirms annotations aren't a caching signal

If re-verifying: check whether `server/discover` is still in the cacheable-operations list (the
changelog's SEP-2549 entry omits it while the caching page includes it — the caching page is the
normative one), and whether any `tools/call` caching has been sanctioned since.
