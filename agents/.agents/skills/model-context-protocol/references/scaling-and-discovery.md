# Scaling Tool Catalogs and Discovering Servers

Two problems that show up past a toy setup: (1) a client connected to several servers accumulates more
tools than the model can select among well, and (2) before any of that, a host needs some way to find
out which MCP servers exist at all.

**This changed in `2026-07-28`.** The protocol still offers no search primitive, but MCP now ships
official host-side guidance — a **Client Best Practices** page covering progressive tool discovery,
dynamic server management, and programmatic tool calling — plus two protocol affordances that exist
specifically to make catalog caching work (`ttlMs`/`cacheScope` and deterministic `tools/list`
ordering). If you remember this area as "the spec says nothing," that's out of date.

## What the protocol itself gives you

`tools/list` still takes exactly one optional param, `cursor` (pagination mechanics in
[primitives.md](primitives.md#pagination)) — **no filter or search parameter**. Change signals are
`notifications/tools/list_changed`, now delivered on a
[`subscriptions/listen`](request-model-and-transports.md#subscriptionslisten) stream rather than a
standalone GET stream.

Two `2026-07-28` additions that matter here:
- **Deterministic ordering.** Servers **SHOULD** return tools in the same order across requests while
  the underlying set is unchanged — explicitly "to enable client-side caching and improve LLM prompt
  cache hit rates." This is the spec addressing the prompt-cache problem directly.
- **Required cache hints.** `tools/list`, the other lists, `resources/read`, and `server/discover` all
  carry `ttlMs` + `cacheScope`, so a host can stop re-listing on every turn. See
  [caching.md](caching.md).
- **`server/discover`** gives capabilities + supported versions + identity in **one** round trip
  instead of probing `tools/list` + `prompts/list` + `resources/list`.

**Why it matters in practice:** tools are model-controlled — the model can only pick from what's
presented (see the [control-model taxonomy](primitives.md#control-model-taxonomy)). The spec's own
framing: with dozens of servers and hundreds of tools, definitions "can consume the majority of the
context window before the model has even read the user's message." Anthropic's internal eval reports
tool-selection accuracy degrading past roughly 30–50 tools. Those are vendor measurements, not spec
claims, but they're why the problem exists.

## Progressive tool discovery (official guidance)

The host fetches `tools/list` as normal but **defers injecting definitions into context**, exposing a
lightweight `search_tools` meta-tool instead and loading full definitions only as needed.

**When to switch:** the spec recommends a **threshold as a percentage of the context window — 1%–5%**.
Below it, just load everything; above it, switch. Don't reach for this machinery on a small catalog.

**Search strategies:** keyword (BM25/regex — effective with descriptive names), embedding (handles
synonyms), **subagent** (a small fast model picks tools — usually works very well, but costs more), or
hybrid. Several providers ship built-in tool search (Anthropic, OpenAI) — prefer the platform's unless
you need specialized retrieval like access-control filtering or domain ranking.

**The three-layer pattern** (illustrative; the layered principle holds regardless of retrieval):

| Layer | Meta-tool | Returns |
| --- | --- | --- |
| 1. **Catalog** | `search_tools({query})` | matching tool names + one-line descriptions only |
| 2. **Inspect** | `get_tool_details({name})` | the full definition (input/output schema, docs) for that one tool |
| 3. **Execute** | the real `tools/call` | — |

**Implementation guidelines**, verbatim in intent from the spec:

| Guideline | Rationale |
| --- | --- |
| Offer multiple detail levels | Let the model choose name-only / name+description / full-schema |
| Cache tool definitions host-side | Memoize after fetching so re-injecting later needs no `tools/list` round trip — **separate from what's in the model's context** |
| Refresh on `list_changed` | Re-index the search catalog when the notification arrives |
| Group tools by server | So the model can reason about related capabilities |

**Dynamic server management** extends the same idea to whole servers: keep a registry of available
servers + descriptions, connect only when the model decides it needs one (`server/discover` →
`tools/list`), and disconnect when done to free context. Works especially well for general-purpose
agents where intent isn't known upfront — and composes with agent skills, where a skill file declares
which servers it needs and the host connects them on invocation.

**Prompt-caching interaction — the sharp edge.** Most providers cache the prompt prefix including the
`tools` array, so adding or removing definitions mid-conversation invalidates it, and the resulting
miss "can cost more tokens than the definitions you removed." Mitigations the spec names:
- **Append** newly discovered definitions after the cache breakpoint rather than re-sorting the array;
- or route every call through **one stable `call_tool({name, args})` meta-tool** so the array never
  changes at all;
- treat server disconnection as a **conversation-boundary** operation, not a per-turn one.

Also: treat a cached list as stale the moment a `list_changed` arrives, even mid-TTL.

## Programmatic tool calling ("code mode")

Instead of the model calling tools directly — where every intermediate result passes through its
context — the model **writes code that calls tools**. The code runs in a sandbox and only the final
result returns. The spec's own illustration: ~100K+ tokens of direct calling versus a ~200-token script
returning a ~15-token summary.

**How it works:** the host converts MCP tool schemas (arguments + `outputSchema`) into a typed API
available inside the sandbox; calls are intercepted and dispatched as `tools/call` by a **host broker**;
the model sees only `console.log` output or a return value.

**Sandbox options the spec lists** (examples, not endorsements — evaluate maturity yourself): Deno or
`isolated-vm` for JavaScript, Monty *(experimental)* for Python, pctx *(early-stage)* for TypeScript,
Wasmtime for anything compiled to Wasm. The integration pattern is identical regardless: inject function
stubs, intercept over an in-process or stdio channel so **network permissions can stay fully denied**,
dispatch as `tools/call`.

**Security considerations — the part that's easy to get wrong:**
- **Per-call authorization still applies.** The broker is the MCP host for spec purposes, so
  human-in-the-loop policy applies to sandbox-originated calls too. **Approving the script does not
  approve every call it makes.** A host may grant categorical approval ("allow `ticketing_createIssue`
  for this run") instead of prompting per iteration, but the broker must still evaluate each call
  against that grant.
- **Cross-server data flow:** a result from server A is **untrusted input** to server B. Output
  truncation alone does not prevent exfiltration.
- **No network access** from the sandbox; **no credentials** in generated code — the host holds tokens
  and adds auth when forwarding. Set timeouts/memory limits. Validate and truncate console output.
- **Error handling:** MCP tool errors arrive as a *successful* response with `isError: true`, not a
  transport failure — generated wrappers should convert that into a thrown exception so model-authored
  code can `try`/`catch`. Surface an uncaught error as the script's result so the model can self-correct;
  the model is responsible for reporting partial side effects already committed.

The two patterns compose: discover which tools you need, load only those schemas, then write one script
that calls several of them — cutting both the definition cost and the result cost.

## Where filtering can happen

Since the protocol provides none:

| Locus | Mechanism | Examples |
| --- | --- | --- |
| Host/client-side | Progressive discovery + dynamic server management as above; or simply letting users enable/disable servers | The spec's own Client Best Practices guidance |
| Server/gateway-side | A wrapping server exposes a small meta-tool set (`search_tools`, `describe_tool`, `execute_tool`) and hides the real catalog | IBM `mcp-context-forge` "virtual meta-server"; `agentic-community/mcp-gateway-registry` (semantic search, identity/policy-scoped so an agent only discovers what it's authorized to use) |
| Inference layer | Provider-native tool search returns references expanded into definitions inline | Anthropic's Tool Search Tool, Claude Code's tool-search default — an API/host feature, not MCP; see the `claude-api` skill for `defer_loading`/`tool_reference`/`ENABLE_TOOL_SEARCH` rather than duplicating it here |

**Namespacing.** There's still no spec-mandated separator for disambiguating same-named tools across
servers — it's host convention. Claude Code prefixes by server name; don't assume every host uses the
same separator, or that it's a protocol requirement.

**Writing discoverable tool descriptions** (portable regardless of host): use a consistent naming prefix
per server so one search matches the group, put task-oriented keywords in the description matching how a
user would actually phrase the request, and prefer specific names (`search_slack_messages`) over generic
ones (`query_slack`) — generic names collide once you're aggregating.

## The MCP Registry — discovering which servers exist (still in preview)

**Status, verified July 2026:** still "currently in preview. Breaking changes or data resets may occur
before general availability." Don't build production dependencies on exact behavior.

**What it is:** a centralized *metadata* repository — not a code host. One standardized `server.json`
per server (unique name; where to find it — npm/PyPI/Docker package or remote URL; execution
instructions; description/capabilities), backed by Anthropic, GitHub, PulseMCP, and Microsoft among
others.

**Namespace verification:** reverse-DNS names (`io.github.user/server-name`, `com.example/server`) tied
to a verified GitHub account or domain via a DNS/GitHub/HTTP challenge — this is what stops publishing
under a namespace you don't own.

**Consumption model — the commonly-missed part:** the Registry is **not** meant to be consumed directly
by hosts. Hosts consume downstream *aggregators* (marketplaces built on its data) via a published
OpenAPI REST spec that the official Registry and others (including private/self-hosted ones) can
implement. Aggregators pull fresh metadata on an infrequent schedule (docs suggest roughly hourly), not
live per-request.

**No private servers.** The official Registry only accepts servers whose install method or endpoint is
publicly reachable. For internal servers, self-host a registry implementing the same OpenAPI interface —
the official Registry's codebase is explicitly not designed to be self-hosted for that purpose.

**Security posture:** the Registry does namespace authentication and spam/abuse prevention (character
limits, validation, manual takedown) and explicitly delegates **code** security scanning to the
underlying package registries and downstream aggregators. Namespace ownership is not a code-safety
guarantee.

## Sources (exact URLs fetched, July 2026)

- https://modelcontextprotocol.io/docs/2026-07-28/develop/clients/client-best-practices — **the new official guidance**: progressive discovery thresholds, search strategies, three-layer pattern, dynamic server management, prompt-caching mitigations, code mode + sandboxes + its security rules
- https://modelcontextprotocol.io/specification/2026-07-28/server/tools (no search/filter param beyond `cursor`; deterministic-ordering SHOULD)
- https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/caching (`ttlMs`/`cacheScope`)
- https://modelcontextprotocol.io/specification/2026-07-28/server/discover
- https://modelcontextprotocol.io/registry/about.md (re-verified: still preview)
- https://www.anthropic.com/engineering/advanced-tool-use — tool-selection-accuracy figures (2025-11-24)
- https://code.claude.com/docs/en/agent-sdk/tool-search — Claude Code tool-search defaults; see `claude-api`

Cited for pattern existence, not individually re-fetched: GitHub `IBM/mcp-context-forge` issue #2230
(virtual meta-server); `agentic-community/mcp-gateway-registry` (semantic-search gateway).

If re-verifying: check whether the Registry has left preview at `/registry/about.md`, and whether
`tools/list` ever gains a search/filter parameter at `/specification/<latest-date>/server/tools`. The
Client Best Practices page is versioned under `/docs/<date>/develop/clients/`, so re-fetch it at the
then-current date.
