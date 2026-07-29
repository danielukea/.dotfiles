# MCP Versioning and Extensions

How the protocol evolves: the dated versioning scheme, per-request version negotiation, the
**era split** introduced by `2026-07-28`, the feature-lifecycle/deprecation policy, and the
separately-governed Extensions track. For the request model itself see
[request-model-and-transports.md](request-model-and-transports.md).

## Versioning

- **Format:** `YYYY-MM-DD` — "the last date backward-incompatible changes were made." A version is
  **not** bumped for backward-compatible additions, so a "Current" dated version keeps evolving.
- **Revision states:** **Draft** (in progress, not for consumption) → **Current** (ready, may still
  receive compatible changes) → **Final** (frozen).
- **Feature states** are tracked separately from revision states — see
  [Feature lifecycle](#feature-lifecycle-sep-2596).
- **URL convention:** `/specification/<date>/...`, aliases `/specification/latest/...` and
  `/specification/draft/...`.

**Known site inconsistency (July 2026):** `/specification/latest` serves `2026-07-28` and every
in-spec link points at `2026-07-28` paths, while `/specification/versioning` still reads "The
**current** protocol version is `2025-11-25`." Treat `2026-07-28` as the newest published revision
(its changelog, deprecation registry, and schema directory all exist), but **re-check that
Current/Final marking before asserting one** — don't repeat either page as gospel.

### Negotiation is per-request now

There is **no negotiation handshake.** Every request declares its version in
`_meta.io.modelcontextprotocol/protocolVersion` (mirrored into the `MCP-Protocol-Version` header on
HTTP), and the server **accepts or rejects each request independently**.

- Unsupported version ⇒ server **MUST** return `UnsupportedProtocolVersionError` (**`-32022`**)
  listing what it does support. Client **SHOULD** pick a mutually supported version and retry, or
  surface an error.
- Clients and servers **MAY** support multiple versions simultaneously — and unlike the legacy era,
  there's no "one agreed version per session," because there's no session.
- Servers **MUST** implement [`server/discover`](request-model-and-transports.md#serverdiscover) so a
  client *can* choose up front, but calling it is optional.

```json
// -32022, replacing the old -32602 "Unsupported protocol version" mismatch error
{ "jsonrpc":"2.0","id":1,"error":{
  "code":-32022,"message":"Unsupported protocol version",
  "data":{"supported":["2026-07-28","2025-11-25"],"requested":"1900-01-01"}} }
```

## Era model: Modern, Legacy, Dual-era

The spec's own vocabulary, and the most useful lens for reading any MCP codebase today:

- **Modern** — conveys version/identity/capabilities as **per-request metadata**. `2026-07-28` and
  later.
- **Legacy** — establishes a session with an **`initialize` handshake**. `2025-11-25` and earlier.
- **Dual-era** — supports both.

**Era is a property of the server, not of a request.** Clients **SHOULD** cache the determination for
the lifetime of the server process (stdio) or origin (HTTP), **MAY** persist it across restarts of the
same server config, and re-probe if the cached assumption later fails.

**Detection** is transport-specific, but the shape is identical: *try modern, and only fall back if
the failure isn't a recognized modern error.*
- **stdio:** probe with `server/discover`. `DiscoverResult` ⇒ modern. A recognized modern error (e.g.
  `-32022`) ⇒ modern but version-mismatched — retry from its `supported` list, **do not** fall back.
  Any other error, or a timeout ⇒ legacy, use `initialize`. The fallback **MUST NOT** be keyed to one
  specific error code; legacy servers answer unknown pre-`initialize` methods with
  implementation-defined codes (commonly `-32601`/`-32602`) or nothing at all.
- **Streamable HTTP:** attempt a modern request; on `400`, **inspect the body** — modern servers also
  use `400` for `-32022`, `-32021`, and header-validation failures. Recognized modern JSON-RPC error
  ⇒ stay modern. Empty or unrecognized body ⇒ fall back to `initialize` (and possibly further to the
  deprecated HTTP+SSE transport).

### Compatibility matrix

| Client | Server | Outcome |
| --- | --- | --- |
| Modern | Modern | **Works.** `server/discover` optional; mismatches surface as `-32022` and the client retries. |
| Modern | Legacy | **Fails.** Server may error, stay silent, or *worse* — process an era-ambiguous method like `tools/call` under legacy semantics. On stdio, probe first to fail deterministically. |
| Dual-era | Modern | Works; client stays modern. |
| Dual-era | Legacy | Works; falls back to `initialize`. |
| Legacy | Modern | **Fails.** `initialize` is an unknown method *and* the request lacks required `_meta`; on HTTP it's rejected `400` for missing headers. Legacy clients have **no fall-forward mechanism.** |
| Legacy | Dual-era | Works, under the negotiated legacy revision. |
| Legacy | Legacy | Works per that revision. |

Two implementer notes worth internalizing:
- A modern-only server **SHOULD** name its supported versions in whatever error it returns to an
  `initialize` request, on any transport — that error message may be the only diagnostic a legacy
  client can ever show a user.
- Even a modern-only client **SHOULD** still probe: some legacy servers don't validate that a request
  arrived after `initialize` and will happily process `tools/call` under legacy semantics. Probing
  converts a silent wrong-semantics success into a deterministic failure.

A dual-era **server** picks behavior from how the client opens — modern `_meta` ⇒ served statelessly;
`initialize` ⇒ legacy semantics scoped to the process (stdio) or session (HTTP) — and **MAY** serve
both eras concurrently on the same endpoint.

## Feature lifecycle (SEP-2596)

New in `2026-07-28`: individual features have their own states, independent of the revision's
Draft/Current/Final state.

| State | Implementer expectation |
| --- | --- |
| **Active** | Implement per its normative requirements. |
| **Deprecated** | Still in the spec, scheduled for removal, migration path documented. New implementations **SHOULD NOT** adopt; existing ones **SHOULD** migrate before earliest removal. |
| **Removed** | Deleted from `draft`, absent from the next Current revision; still documented in the last Final revision it appeared in. |

- **Minimum window: 12 months** Deprecated before becoming *eligible* for removal (≥90 days under
  the expedited-removal exception). "Earliest removal" is eligibility, not a date — actual removal is
  a Core Maintainer decision at release prep and may come later.
- Deprecation requires a SEP naming the feature, the rationale, and the migration path (or an
  explicit "none required"). A Deprecated feature **MAY** be restored to Active by a superseding SEP.
- **SDKs are not bound by it:** removal from the spec doesn't oblige an SDK to drop the feature —
  that's the SDK's own revision-support policy. (Concrete example: `mcp-ruby-sdk`.)
- There's a **[deprecated-features registry](https://modelcontextprotocol.io/specification/2026-07-28/deprecated)**
  page — a derived view; the per-feature notices and changelog entries are the normative records.

### Currently deprecated

| Feature | SEP | Deprecated in | Migration |
| --- | --- | --- | --- |
| **Roots** | SEP-2577 | `2026-07-28` | Pass directories/files via tool params, resource URIs, or server config |
| **Sampling** | SEP-2577 | `2026-07-28` | Integrate directly with LLM provider APIs |
| **Logging** | SEP-2577 | `2026-07-28` | `stderr` on stdio; OpenTelemetry for observability |
| **Dynamic Client Registration** | PR #2858 | `2026-07-28` | Client ID Metadata Documents (CIMD) |
| `includeContext: "thisServer"`/`"allServers"` | SEP-2596 | `2025-11-25` | Omit, or use `"none"` |
| HTTP+SSE transport | SEP-2596 | `2025-03-26` | Streamable HTTP |

The first four are eligible for removal in the first revision released on or after **2027-07-28**;
`includeContext` follows Sampling. **Nothing has been Removed under this policy yet.**

## Recent version deltas

**`2026-07-28` vs `2025-11-25` — an era break, not an increment.** Three structural changes, then the
fallout:
- **Stateless / per-request** (SEP-2575): `initialize` + `notifications/initialized` **removed**;
  version, `clientCapabilities`, `clientInfo` move into per-request `_meta`; `server/discover` added
  as a mandatory server RPC.
- **Sessions removed** (SEP-2567): no `Mcp-Session-Id`; cross-call state becomes server-minted handles
  passed as ordinary tool arguments.
- **MRTR** (SEP-2322): server-initiated requests replaced by `InputRequiredResult` + client retry —
  see [mrtr.md](mrtr.md).

Also: `subscriptions/listen` replaces the HTTP GET stream *and* `resources/subscribe`/`unsubscribe`;
**removed** `ping`, `logging/setLevel`, `notifications/roots/list_changed`,
`notifications/elicitation/complete`, `elicitationId`, SSE resumability (`Last-Event-ID` + event ids),
`tasks/list`, `tasks/result`; **required** `resultType` on every result; **required** `Mcp-Method` /
`Mcp-Name` headers plus `x-mcp-header` → `Mcp-Param-*` (SEP-2243); **required** `ttlMs`/`cacheScope`
via `CacheableResult` (SEP-2549) and deterministic `tools/list` ordering; error-code allocation policy
(`-32020`–`-32099` spec-reserved; `HeaderMismatch` `-32020`, `MissingRequiredClientCapability`
`-32021`, `UnsupportedProtocolVersion` `-32022`); resource-not-found `-32002` → `-32602`; closing an
SSE stream now **means cancel**; `inputSchema`/`outputSchema` loosened to any JSON Schema 2020-12
keywords with `$ref`-resolution and composition-bound rules (SEP-2106); OTel `_meta` conventions
documented (SEP-414); OAuth `iss` validation per RFC 9207 (SEP-2468), `application_type` on DCR
(SEP-837), issuer-bound client credentials (SEP-2352).

**`2025-11-25` vs `2025-06-18`:** OIDC Discovery 1.0 for AS discovery; icons on
tools/resources/templates/prompts; incremental scope consent via `WWW-Authenticate` step-up;
`ElicitResult`/`EnumSchema` rework + URL-mode elicitation; tool calling in sampling; OAuth CIMD added
as *recommended*; experimental Tasks; stderr may carry all log levels; **403 required** for invalid
Origin; input-validation errors reclassified as tool execution errors; JSON Schema 2020-12 default.

**`2025-06-18` vs `2025-03-26`:** removed JSON-RPC batching; structured tool output; servers
classified as OAuth Resource Servers; RFC 8707 Resource Indicators required; elicitation added;
resource links in tool results; `MCP-Protocol-Version` header required.

(`2024-11-05` was the HTTP+SSE / JSON-RPC-batching era — batching removed, transport deprecated.)

## Extensions

**A separate governance track from the dated core spec — don't present it at the same confidence
level as core `MUST`/`SHOULD` text.** Extensions (formalized by **SEP-2133**) live outside
`/specification/<date>/` at `/extensions/...`, evolve on their own repos and timelines
(`modelcontextprotocol/ext-*`) without core-maintainer review, and are **always disabled by default**.

**Identifier format:** `{vendor-prefix}/{extension-name}`, same rules as [`_meta`
keys](request-model-and-transports.md#per-request-metadata-_meta) but with a **mandatory** prefix.
Official: `io.modelcontextprotocol`. Third parties: a reversed domain you own (`com.example/…`).

**Negotiation** rides the per-request model now — there's no handshake to negotiate in:
- **Client** advertises inside `_meta["io.modelcontextprotocol/clientCapabilities"].extensions` **on
  every request**.
- **Server** advertises in the `server/discover` result's `capabilities.extensions`.

```json
// client, per request
"io.modelcontextprotocol/clientCapabilities": {
  "extensions": { "io.modelcontextprotocol/ui": { "mimeTypes": ["text/html;profile=mcp-app"] } } }
// server, in DiscoverResult
"capabilities": { "tools": {}, "extensions": { "io.modelcontextprotocol/ui": {} } }
```

An empty settings object means "supported, no configurable settings." **Graceful degradation is the
implementer's job:** fall back to core behavior, or reject with an error if the extension was
mandatory — and document which, per extension. Extensions **SHOULD** prefer capability flags or
in-settings versioning over minting a new identifier; a genuinely breaking change needs a new one
(`…/my-extension-v2`).

**Published official extensions:**
- **MCP Tasks** (`io.modelcontextprotocol/tasks`) — async execution of long-running operations with
  polling, mid-flight input, and durable handles. **Left the core spec in `2026-07-28`** and was
  redesigned (SEP-2663): blocking `tasks/result` replaced by polling `tasks/get`, new `tasks/update`
  for client→server input, `tasks/list` removed, and servers may now return task handles unsolicited
  without per-request opt-in.
- **MCP Apps** (`io.modelcontextprotocol/ui`) — interactive sandboxed UI (charts, forms, video)
  rendered inline, referenced from a tool's `_meta` via a `postMessage` dialect. Deep detail is out of
  scope here; see the extension's own docs.
- **OAuth Client Credentials** — machine-to-machine, no user/browser.
- **Enterprise-Managed Authorization** — centralized access control for enterprise deployments.

**Not an extension yet, despite appearances: "Skills over MCP."** `/specification/latest` lists it
among "notable extensions," but it is currently a **Working Group** whose direction lives in
**SEP-2640 (Skills Extension, Extensions Track)** — an open PR, with no entry in
`/extensions/overview`. Treat it as in-flight, not implementable.

There's also an **experimental-extension** incubation path (`experimental-ext-*` repos, each tied to a
Working/Interest Group, with Core Maintainers able to archive them) for ideas pre-SEP — unstable by
definition. Graduation to official goes through the normal SEP Extensions Track, which requires at
least one reference implementation in an official SDK before review.

## Sources (exact URLs fetched, July 2026)

- https://modelcontextprotocol.io/specification/latest (resolves to `2026-07-28`)
- https://modelcontextprotocol.io/specification/versioning (the stale "current is 2025-11-25" line)
- https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning (era model, matrix, negotiation)
- https://modelcontextprotocol.io/specification/2026-07-28/changelog
- https://modelcontextprotocol.io/specification/2026-07-28/deprecated
- https://modelcontextprotocol.io/community/feature-lifecycle (SEP-2596 policy)
- https://modelcontextprotocol.io/extensions/overview (official list + per-request negotiation examples)
- https://modelcontextprotocol.io/community/working-groups/skills-over-mcp (confirms WG status, SEP-2640)
- https://modelcontextprotocol.io/specification/2025-11-25/changelog, `.../2025-06-18/changelog`

If re-verifying: `/specification/<latest-date>/changelog` is the fastest read of what moved, and
`/specification/<latest-date>/deprecated` now tells you what's on the way out. Re-check
`/extensions/overview` — that list is expected to grow, and Skills over MCP is the next likely entry.
