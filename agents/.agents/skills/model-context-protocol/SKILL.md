---
name: model-context-protocol
description: Deep reference for the Model Context Protocol (MCP) — the stateless JSON-RPC standard connecting AI hosts to external tools. Use when building, reviewing, or debugging an MCP server or client: primitives, per-request metadata, server discovery, multi round-trip requests, subscriptions, transports, OAuth, versioning, caching. Trigger on "MCP server", "tools/list", "stateless MCP", "confused deputy". Language-agnostic — see mcp-ruby-sdk for Ruby.
---

# Model Context Protocol (MCP)

Deep reference for [MCP](https://modelcontextprotocol.io/), the open standard for connecting AI
applications to external tools and data. **This file is a router** — it states the mental model, maps
each concept to a one-line "when," and gives you gotcha hooks. Full treatments (JSON-RPC message
shapes, field-by-field detail, attack patterns) live in `references/`; open the linked file when
you're at that decision point.

**Spec version: `2026-07-28`.** Treat this as an **era break, not an increment** — it is the largest
breaking change in the protocol's history:

1. **Stateless** (SEP-2575) — the `initialize`/`notifications/initialized` handshake is **removed**.
   Every request carries its own version, capabilities, and identity in `_meta`. New mandatory RPC:
   `server/discover`.
2. **No sessions** (SEP-2567) — `Mcp-Session-Id` is **removed**; cross-call state becomes
   server-minted handles passed as ordinary tool arguments.
3. **MRTR** (SEP-2322) — servers can no longer send their own requests. Sampling, elicitation, and
   roots are now answered *by* the client on a retry of its own request.

Versions are dated, not semver: a version string means "the last date backward-incompatible changes
were made." Don't assume a version you remember is still latest — and note the spec site currently
contradicts itself about which revision is "Current," so check
[references/versioning-and-extensions.md](references/versioning-and-extensions.md#versioning) before
asserting one.

## The Core Mental Model

MCP is "USB-C for AI applications" — one standard connector instead of an integration per app-per-tool
(M×N collapsed to M+N). Three roles:

- **Host** — the AI application the user interacts with (Claude Code, Claude Desktop, an IDE).
  Coordinates one or more clients.
- **Client** — the protocol connector inside the host. **One client per server connection.**
- **Server** — a program offering context/capabilities: **local** (stdio subprocess) or **remote**
  (Streamable HTTP, many clients).

Two layers:
- **Data layer** — JSON-RPC 2.0: requests (`id` + `method`), notifications (no `id`, no response), and
  the primitives built on them. Every result now carries a required `resultType`.
- **Transport layer** — **stdio** or **Streamable HTTP** (POST-only).

**A request is self-contained, and a connection is not a conversation.** No state may be inferred from
earlier requests, even on the same stream. This is the fact everything else follows from.

**Feature ownership:** servers offer Tools, Resources, Prompts. Clients offer **Elicitation** — plus
Sampling, Roots, and Logging, all three now **Deprecated** (SEP-2577) but still fully functional until
at least 2027-07-28.

## Surface → Reference

The `Need` column is your "when to reach for this" index; each row routes to the file with the full treatment.


| Need | Reach for | Reference |
| --- | --- | --- |
| Model should **do** something (call an API, mutate state) | `Tools` — `tools/list`, `tools/call` | [primitives.md](references/primitives.md#tools) |
| App feeds the model **read-only** context (files, rows, docs) | `Resources` — `resources/list`, `resources/read` | [primitives.md](references/primitives.md#resources) |
| A curated, parameterized workflow the **user** explicitly picks | `Prompts` — `prompts/list`, `prompts/get` | [primitives.md](references/primitives.md#prompts) |
| Server needs missing info or confirmation from the user mid-workflow | `Elicitation` — `elicitation/create` (`form`/`url` mode) | [primitives.md](references/primitives.md#elicitation-active) |
| Server needs LLM reasoning, or which directories are in scope | `Sampling` / `Roots` — **both Deprecated**, migrate | [primitives.md](references/primitives.md#client-features--all-delivered-via-mrtr) |
| "How does a server ask the client for anything?" | **MRTR** — `InputRequiredResult`, `inputRequests`, `requestState` | [mrtr.md](references/mrtr.md) |
| What every request must carry; capability negotiation without a handshake | per-request `_meta`, `server/discover` | [request-model-and-transports.md](references/request-model-and-transports.md#per-request-metadata-_meta) |
| stdio vs HTTP, required headers, why there's no session | stdio / Streamable HTTP (POST-only) | [request-model-and-transports.md](references/request-model-and-transports.md#transports) |
| Server-pushed change notifications / watching a resource | `subscriptions/listen` | [request-model-and-transports.md](references/request-model-and-transports.md#subscriptionslisten) |
| "Does my client/server support version X?" / interop with old code | dated versions, per-request negotiation, **Modern/Legacy/Dual-era** + compatibility matrix | [versioning-and-extensions.md](references/versioning-and-extensions.md#era-model-modern-legacy-dual-era) |
| "Is this feature going away?" | feature lifecycle (SEP-2596) + deprecation registry | [versioning-and-extensions.md](references/versioning-and-extensions.md#feature-lifecycle-sep-2596) |
| "Is this core-spec or an optional Extension?" (Tasks, MCP Apps) | `capabilities.extensions`, SEP-2133 | [versioning-and-extensions.md](references/versioning-and-extensions.md#extensions) |
| Auth flow, or "is this MCP server/proxy exploitable?" | OAuth 2.1 + named attack patterns | [security.md](references/security.md) |
| Too many tools across too many servers; or how to find/publish a server | progressive discovery, code mode, gateway pattern, MCP Registry (preview) | [scaling-and-discovery.md](references/scaling-and-discovery.md) |
| "Can I cache this?" / "do I need to scope the cache?" | `ttlMs`/`cacheScope` — **now required** | [caching.md](references/caching.md) |

## Gotchas (hooks — full detail in references)

- **Looking for `initialize`, `Mcp-Session-Id`, `resources/subscribe`, `ping`, `logging/setLevel`, or
  `Last-Event-ID`?** All removed in `2026-07-28`. Finding them in code tells you it targets the
  **Legacy** era — that's a version fact to establish, not a bug to fix.
- **An MRTR retry MUST use a new JSON-RPC `id`**, and must echo `requestState` byte-for-byte without
  parsing it — see [mrtr.md](references/mrtr.md).
- **`requestState` is attacker-controlled.** It round-trips through the client; integrity-protect it
  (HMAC/AEAD) if it touches authorization or business logic.
- **Closing an SSE stream now *means cancel*** on Streamable HTTP — the exact reverse of `2025-11-25`,
  where disconnection explicitly did not imply cancellation.
- **A broken stream loses the request.** No resumability; re-issue as a new request with a new id.
- **Header/body mismatch is a hard `-32020`**, not a warning — `Mcp-Method`/`Mcp-Name`/
  `MCP-Protocol-Version` must match the body exactly.
- **`ttlMs`/`cacheScope` are required now**, not optional; and a cached response containing
  user-specific data (`cacheScope: "private"`) **MUST NOT** cross authorization contexts.
- **Deprecated ≠ removed.** Roots/Sampling/Logging are fully functional with ≥12-month windows; don't
  tell someone their working code is broken.
- **"Session hijacking" has a successor: state handle hijacking.** Possession of a state handle is not
  authentication — bind handles to the authenticated user server-side.
- Model acts on a malicious instruction hidden in a tool's own metadata — tool descriptions and
  annotations are **not authenticated**; treat them as untrusted unless the server is.
- Server assumes `roots/list` sandboxes it — Roots are **advisory, never enforced**; real security is
  OS-level.
- Model doesn't self-correct after a failed tool call — the failure came back as a JSON-RPC protocol
  error instead of `isError:true` inside a normal result.
- stdio client can't parse a response it clearly received — something wrote non-JSON-RPC text to
  **stdout**; stdout is protocol-only, all logging goes to stderr, and stderr is never an error signal.
- A token issued for one MCP server also works elsewhere, or gets forwarded downstream — missing
  **audience validation**; token passthrough is an explicitly forbidden anti-pattern.
- OAuth flow fails at the AS for no obvious reason — client skipped verifying **PKCE support**
  (`code_challenge_methods_supported`) and MUST refuse if it's absent.
- `readOnlyHint`/`idempotentHint` treated as "safe to cache" — **unverified hints**, not a caching
  signal; a server can lie.
- Assumed Tasks/MCP Apps ship with every conformant server — both are opt-in **Extensions**
  (SEP-2133), negotiated via `capabilities.extensions`.
- **An SDK may lag the spec by a whole era.** Spec-level statelessness does not mean your SDK
  implements it (concrete case: `mcp-ruby-sdk`).

## Bundled References

- **[references/primitives.md](references/primitives.md)** — architecture (now stateless), JSON-RPC +
  `resultType` + the error-code allocation policy + `_meta`, and every primitive/utility with its
  Active/Deprecated status: Tools, Resources, Prompts, Elicitation, Sampling, Roots, Logging,
  Pagination, Completion, Progress, Cancellation, and Tasks-as-an-extension.
- **[references/request-model-and-transports.md](references/request-model-and-transports.md)** — the
  per-request `_meta` model that replaced the handshake, `server/discover`, stdio + POST-only
  Streamable HTTP (required headers, `x-mcp-header`, status codes, no sessions, no resumability), and
  `subscriptions/listen`.
- **[references/mrtr.md](references/mrtr.md)** — Multi Round-Trip Requests: the three types, where the
  fields live, the retry contract, and `requestState` security.
- **[references/versioning-and-extensions.md](references/versioning-and-extensions.md)** — dated
  versioning, per-request negotiation, the Modern/Legacy/Dual-era model + compatibility matrix, the
  SEP-2596 feature lifecycle and what's currently deprecated, version deltas, and the Extensions track.
- **[references/security.md](references/security.md)** — OAuth 2.1 (incl. CIMD-over-DCR, RFC 9207
  `iss`, issuer-bound credentials) and every named attack pattern, including **state handle hijacking**
  and `requestState` tampering.
- **[references/scaling-and-discovery.md](references/scaling-and-discovery.md)** — the official
  progressive-discovery and code-mode guidance, prompt-cache interaction, gateway/meta-tool pattern,
  and the MCP Registry (preview).
- **[references/caching.md](references/caching.md)** — the now-mandatory `ttlMs`/`cacheScope` model,
  cache keys, pagination/notification interaction, and why tool annotations aren't a caching signal.

---

*Sources: [modelcontextprotocol.io](https://modelcontextprotocol.io/) `/specification/2026-07-28/`
pages plus `/docs/2026-07-28/`, `/extensions/`, and `/community/feature-lifecycle`, fetched directly
July 2026 — not reconstructed from training memory. Each reference file carries its own exact source
URLs so this skill can be re-verified against a newer spec revision.*
