---
name: model-context-protocol
description: Deep reference for the Model Context Protocol (MCP) — the open, JSON-RPC 2.0-based standard connecting AI applications (hosts) to external tools and data via clients and servers. Use whenever building, reviewing, or debugging an MCP server or client in ANY language, deciding which primitive (Tool/Resource/Prompt/Sampling/Roots/Elicitation) a piece of server functionality should be, implementing or reviewing the `initialize` handshake and capability negotiation, choosing or debugging a transport (stdio, Streamable HTTP), wiring up MCP's OAuth 2.1 authorization framework, reasoning about MCP protocol versioning (`2025-11-25`, `2025-06-18`, etc) or the SEP-2133 Extensions track, scaling a large tool catalog across many servers, publishing/discovering servers via the MCP Registry, or deciding what's safe to cache (tool/resource lists, tool call results). Also trigger on "MCP server", "MCP client", "tools/list", "tools/call", "JSON-RPC MCP", "Mcp-Session-Id", "Streamable HTTP", "confused deputy", "MCP caching", "MCP extensions", "MCP registry" in an MCP context, or "is this MCP spec compliant?". Language/SDK-agnostic — for the official Ruby SDK's concrete API, see `mcp-ruby-sdk`.
---

# Model Context Protocol (MCP)

Deep reference for [MCP](https://modelcontextprotocol.io/), the open standard for connecting AI
applications to external tools and data. **This file is a router** — it states the mental model,
maps each concept to a one-line "when," and gives you gotcha hooks. Full treatments (JSON-RPC
message shapes, field-by-field detail, attack patterns) live in `references/`; open the linked
file when you're at that decision point.

**Spec version:** current is **`2025-11-25`** (as of this writing, July 2026) — one revision past
`2025-06-18`, which is itself past `2025-03-26` and the original `2024-11-05`. Versions are dated,
not semver: a version string means "the last date backward-incompatible changes were made," and
a "Current" version keeps receiving compatible additions. Don't assume a version you remember is
still latest — check [references/lifecycle-transports-versioning.md](references/lifecycle-transports-versioning.md#versioning)
before asserting one.

## The Core Mental Model

MCP is often described as "USB-C for AI applications" — a standard connector instead of a custom
integration per app-per-tool (the M×N problem collapsed to M+N). Three roles:

- **Host** — the AI application the user interacts with (Claude Code, Claude Desktop, an IDE). Coordinates one or more clients.
- **Client** — the protocol connector living inside the host. **One client per server connection.**
- **Server** — a program that offers context/capabilities: **local** (spawned via stdio, usually 1 client) or **remote** (Streamable HTTP, usually many clients).

Two layers:
- **Data layer** — JSON-RPC 2.0 messages: requests (`id` + `method`, expects a response), notifications (no `id`, no response), and the lifecycle + primitives built on top of them.
- **Transport layer** — the channel carrying those messages: **stdio** or **Streamable HTTP**.

**Feature ownership:** servers offer Tools, Resources, Prompts. Clients offer Sampling, Roots,
Elicitation, Logging.

## Reach for this skill when

- Designing what primitive (Tool vs Resource vs Prompt vs Sampling vs Roots vs Elicitation) a piece of server functionality should be
- Writing or reviewing the `initialize` handshake / capability negotiation for a custom MCP implementation
- Choosing or debugging a transport (stdio vs Streamable HTTP) — message framing, session headers, resumable streams
- Wiring up or reviewing MCP's OAuth 2.1 authorization flow, or auditing an MCP server/proxy for confused-deputy, token-passthrough, or SSRF vulnerabilities
- Something "isn't spec compliant" and you need the exact method name, field name, or MUST/SHOULD requirement — not a paraphrase
- Reasoning about protocol version compatibility ("does my server work with a `2025-06-18` client?") or whether a feature is core-spec vs. a separately-governed Extension
- Deciding what to cache (and how to scope it) across tool/resource/prompt lists or tool-call results
- A client is accumulating tools across many servers and selection accuracy is degrading, or you need to publish/discover a server via the MCP Registry

## Surface → Reference

| Need | Reach for | Reference |
| --- | --- | --- |
| Model should **do** something (call an API, mutate state) | `Tools` — `tools/list`, `tools/call` | [primitives.md](references/primitives.md#tools) |
| App feeds the model **read-only** context (files, rows, docs) | `Resources` — `resources/list`, `resources/read`, `resources/subscribe` | [primitives.md](references/primitives.md#resources) |
| A curated, parameterized workflow the **user** explicitly picks | `Prompts` — `prompts/list`, `prompts/get` | [primitives.md](references/primitives.md#prompts) |
| Server needs LLM reasoning mid-task without its own model/API key | `Sampling` — `sampling/createMessage` | [primitives.md](references/primitives.md#sampling) |
| Server needs to know which directories/workspaces are in scope | `Roots` — `roots/list` (**advisory only**) | [primitives.md](references/primitives.md#roots) |
| Server needs missing info or confirmation from the user mid-workflow | `Elicitation` — `elicitation/create` (`form`/`url` mode) | [primitives.md](references/primitives.md#elicitation) |
| Handshake, capability negotiation, shutdown, timeouts | `initialize` / `notifications/initialized` | [lifecycle-transports-versioning.md](references/lifecycle-transports-versioning.md#lifecycle) |
| Local-process vs remote transport, session headers, resumable streams | stdio / Streamable HTTP | [lifecycle-transports-versioning.md](references/lifecycle-transports-versioning.md#transports) |
| "Does my client/server support version X?" | dated version scheme + negotiation | [lifecycle-transports-versioning.md](references/lifecycle-transports-versioning.md#versioning) |
| "Is this a core-spec feature or an optional Extension?" (Apps, Tasks, OAuth Client Credentials) | `capabilities.extensions`, SEP-2133 | [lifecycle-transports-versioning.md](references/lifecycle-transports-versioning.md#extensions) |
| Auth flow, or "is this MCP server/proxy exploitable?" | OAuth 2.1 framework + named attack patterns | [security.md](references/security.md) |
| Too many tools across too many servers, or "how do I find/publish an MCP server?" | pagination ceiling, gateway/meta-tool pattern, MCP Registry (preview) | [scaling-and-discovery.md](references/scaling-and-discovery.md) |
| "Can I cache this?" / "do I need to scope the cache?" | `cacheScope`/`ttlMs` (draft), tool-annotation caveats | [caching.md](references/caching.md) |

## Gotchas (hooks — full detail in references)

| Symptom | Real cause |
| --- | --- |
| Model acts on a malicious instruction hidden in a tool's own metadata | Tool descriptions/annotations are **not authenticated** — treat them as untrusted unless the server itself is trusted (tool poisoning / prompt injection) |
| Server assumes `roots/list` keeps it sandboxed to those directories | Roots are **advisory, not enforced** — real security must come from OS-level permissions/sandboxing, because servers run code the client can't control |
| Model doesn't self-correct after a failed tool call | The failure was returned as a JSON-RPC **protocol error** instead of `isError:true` inside a normal result — validation/business failures belong in the result so the model can retry |
| stdio server "connects" but the handshake hangs or garbles | Something wrote non-JSON-RPC text to **stdout** (a stray `print`/banner/log line) — stdout is protocol-only; all logging goes to stderr, and stderr is never an error signal |
| Every HTTP request after `initialize` returns 400 | Client dropped the **`Mcp-Session-Id`** header the server assigned in the `InitializeResult` |
| Remote server 403s a browser-based client | Server is correctly validating `Origin` (DNS-rebinding defense) — not a bug; fix the client's Origin, don't disable the check |
| A token issued for one MCP server also works elsewhere, or gets forwarded downstream | Missing **audience validation** — servers MUST NOT accept or pass through tokens not issued specifically for them ("token passthrough" is an explicitly forbidden anti-pattern) |
| OAuth flow fails at the authorization server for no obvious reason | Client skipped verifying **PKCE support** (`code_challenge_methods_supported`) before proceeding — MUST refuse if it's absent |
| "This tool is `readOnlyHint:true`/`idempotentHint:true`, safe to cache its result" | Those are **unverified hints**, not spec-endorsed for caching decisions — a server can lie about them; see [caching.md](references/caching.md) |
| Cached a tool/resource list, then served it to the wrong user | Cached responses containing user-specific data (`cacheScope: "private"` in the draft caching model) **MUST NOT be shared across authorization contexts** — a different access token needs a different cache entry |
| Assumed Tasks/MCP Apps ship with every `2025-11-25`-conformant server | Both are organized under the separately-governed **SEP-2133 Extensions track**, always opt-in and negotiated via `capabilities.extensions` — not guaranteed just because the server speaks `2025-11-25` |

## Bundled References

- **[references/primitives.md](references/primitives.md)** — Host/Client/Server architecture, JSON-RPC framing and the `_meta` convention, every primitive (Tools, Resources, Prompts, Sampling, Roots, Elicitation, Logging), and the other utilities (Pagination, Completion, Progress, Cancellation): who controls it, exact methods/fields, minimal real examples, when to reach for it, primitive-specific traps.
- **[references/lifecycle-transports-versioning.md](references/lifecycle-transports-versioning.md)** — the `initialize` handshake, stdio and Streamable HTTP transports (framing, session IDs, resumability), the dated versioning scheme and negotiation mechanics, the deltas between the last three spec revisions, and the separately-governed Extensions track (SEP-2133: negotiation, official extensions incl. MCP Apps and MCP Tasks).
- **[references/security.md](references/security.md)** — the OAuth 2.1 authorization framework (discovery, PKCE, resource indicators, token validation) and every named attack pattern from the spec's security best-practices page (confused deputy, token passthrough, SSRF via OAuth discovery, session hijacking, local server compromise, auth-URL injection, elicitation URL phishing, scope minimization).
- **[references/scaling-and-discovery.md](references/scaling-and-discovery.md)** — what MCP itself offers for large tool catalogs (pagination + `list_changed`, and nothing else), the gateway/meta-tool pattern, tool-description writing tips, and the MCP Registry (currently in preview) for publishing/discovering servers.
- **[references/caching.md](references/caching.md)** — carefully tiered released-vs-draft-vs-community-vs-inference: the unreleased `ttlMs`/`cacheScope` caching model, why tool annotations aren't a spec-endorsed caching signal, and why cached responses with user-specific data must be scoped per authorization context.

---

*Sources: [modelcontextprotocol.io](https://modelcontextprotocol.io/) docs and `/specification/2025-11-25/` pages, fetched directly July 2026 — not reconstructed from training memory. Each reference file below carries its own exact source URLs so this skill can be re-verified against a newer spec revision.*
