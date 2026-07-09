# MCP Versioning and Extensions

How the protocol evolves over time: the dated versioning scheme, how client and server negotiate a
version, the deltas between recent revisions, and the separately-governed Extensions track. For
what happens at connection time (the `initialize` handshake, transports), see
[lifecycle-and-transports.md](lifecycle-and-transports.md).

## Versioning

- **Format:** `YYYY-MM-DD` — "the last date backward-incompatible changes were made." A version is
  **not** bumped for backward-compatible additions, so a "Current" dated version keeps evolving.
- **Revision states:** **Draft** (in progress, not for consumption) → **Current** (ready, may
  still receive compatible changes — currently `2025-11-25`) → **Final** (frozen).
- **Feature states:** a feature can be **Deprecated** (stays in the spec ≥12 months, or ≥90 days
  under expedited removal, with a migration path) then eventually **Removed**.
- **URL convention:** `/specification/<date>/...`, with aliases `/specification/latest/...` and
  `/specification/draft/...`.

**Negotiation mechanics:**
- Client MUST send a supported version in `initialize` (SHOULD be its latest).
- If the server supports that exact version, it MUST echo it back. Otherwise it MUST respond with
  another version it supports (SHOULD be its own latest).
- If the client doesn't support the version the server returned, it SHOULD disconnect.
- Both sides MAY support multiple versions but MUST agree on exactly one per session.

```json
// mismatch error (JSON-RPC -32602)
{ "jsonrpc":"2.0","id":1,"error":{
  "code":-32602,"message":"Unsupported protocol version",
  "data":{"supported":["2024-11-05"],"requested":"1.0.0"}} }
```

(The HTTP-level `MCP-Protocol-Version` header that carries the negotiated version on subsequent
requests is covered in [lifecycle-and-transports.md](lifecycle-and-transports.md#transports).)

### Recent version deltas

**`2025-11-25` (current) vs `2025-06-18`:**
- Authorization server discovery also supports **OpenID Connect Discovery 1.0**.
- Tools/resources/templates/prompts can expose **icons**.
- **Incremental scope consent** via `WWW-Authenticate` step-up authorization.
- `ElicitResult`/`EnumSchema` reworked (titled/untitled, single/multi-select enums); **URL-mode elicitation** added.
- **Tool calling in sampling** (`tools`/`toolChoice`).
- **OAuth Client ID Metadata Documents (CIMD)** added as the *recommended* registration mechanism.
- Experimental **Tasks** (durable/pollable requests).
- Minor but sharp: stderr may carry *all* log levels; HTTP **403 required** for invalid Origin;
  input-validation errors reclassified as **tool execution errors**, not protocol errors; SSE
  streams may be polled (server can disconnect at will); **JSON Schema 2020-12** is now the default
  dialect; `WWW-Authenticate` made optional with `.well-known` fallback (RFC 9728 alignment).

**`2025-06-18` vs `2025-03-26`:**
- **Removed JSON-RPC batching.**
- Added **structured tool output**.
- MCP servers classified as OAuth **Resource Servers** (+ protected resource metadata for AS discovery).
- **RFC 8707 Resource Indicators required** in clients (anti token-theft).
- New security-best-practices page + expanded authz security considerations.
- Added **elicitation**; added **resource links** in tool results.
- Required **`MCP-Protocol-Version` header** on subsequent HTTP requests.
- Lifecycle "Operation" requirement: SHOULD → MUST.

(`2024-11-05` was the original transport era — HTTP+SSE with JSON-RPC batching — both since removed.)

## Extensions

**A separate governance track from the dated core spec — don't present it at the same
confidence level as `MUST`/`SHOULD` core-spec text.** Extensions (formalized by **SEP-2133**) are
optional additions living outside `/specification/<date>/`, at top-level paths like
`/extensions/...`. They evolve on their own repos/timelines, independent of core-spec review, and
are **always disabled by default** — explicit opt-in only.

**Identifier format:** `{vendor-prefix}/{extension-name}`, following the same reserved-prefix rules
as [`_meta` keys](primitives.md) — official extensions use `io.modelcontextprotocol`; third parties
should use a reversed domain they own (`com.example/my-extension`).

**Negotiation** — a dedicated `extensions` field inside each side's `capabilities`, alongside the
primitive capabilities negotiated during the [handshake](lifecycle-and-transports.md#lifecycle):

```json
// client -> server (initialize request)
{ "capabilities": { "extensions": { "io.modelcontextprotocol/ui": { "mimeTypes": ["text/html;profile=mcp-app"] } } } }
// server -> client (initialize response)
{ "capabilities": { "extensions": { "io.modelcontextprotocol/ui": {} } } }
```

An empty settings object means "no configurable settings, just support." **Graceful degradation is
the implementer's job, not the protocol's:** if one side doesn't support an extension the other
offers, fall back to core behavior, or reject with an error if the extension was mandatory for that
request — document which, per extension.

**Officially published extensions today** (each with its own repo under `modelcontextprotocol/ext-*`
— maturity varies per extension, check its own docs before relying on specifics):
- **OAuth Client Credentials** — machine-to-machine auth flow, no user/browser involved.
- **Enterprise-Managed Authorization** — centralized access control for enterprise deployments.
- **MCP Apps** — servers can return interactive sandboxed UI (charts, forms, video) inline in a
  conversation, referenced from a tool's `_meta` and rendered via a `postMessage`-based dialect.
  Deep implementation detail is out of scope here — see the extension's own docs if you're building
  one; this skill only covers that it exists and how it's negotiated.
- **MCP Tasks** — durable/pollable long-running requests (see
  [primitives.md](primitives.md#other-utilities)); note this *originated* as an experimental
  `2025-11-25` core-spec feature and has since moved to this extensions track.

There's also an **experimental-extension** incubation path (`experimental-ext-*` repos, tied to a
Working/Interest Group) for ideas that haven't gone through the SEP process yet — treat anything
found there as unstable by definition.

## Sources (exact URLs fetched, July 2026)

- https://modelcontextprotocol.io/specification/
- https://modelcontextprotocol.io/specification/versioning
- https://modelcontextprotocol.io/specification/2025-11-25/changelog
- https://modelcontextprotocol.io/specification/2025-06-18/changelog
- https://modelcontextprotocol.io/extensions/overview.md (fetched directly, confirmed preview/separate-track status, negotiation JSON examples, and the official extensions list)

If re-verifying: the changelog page for the *then-current* version is the fastest way to see what
moved since these notes were written — check `/specification/<latest-date>/changelog`. For
extensions specifically, re-check `/extensions/overview.md` — that list is expected to grow.
