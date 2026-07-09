# Scaling Tool Catalogs and Discovering Servers

Two distinct problems that both show up once you're past a toy setup: (1) a client connected to
several servers accumulates more tools than the model can select among well, and (2) before any of
that, a host needs some way to find out which MCP servers exist at all. MCP the protocol has very
little to say about either — most of the real machinery lives one layer up, in hosts, gateways, and
a separate registry project.

## Tool catalogs at scale — what MCP itself gives you (not much)

**Confirmed from the current spec:** `tools/list` takes exactly one optional param, `cursor` (see
[primitives.md](primitives.md#other-utilities) for pagination mechanics) — there is no filter or
search parameter at the protocol level. The only other lever is
`notifications/tools/list_changed`, which is a *change* signal, not a *search* primitive. That's
the complete picture at the spec layer.

**Why it matters in practice:** tools are model-controlled — the model can only pick from what's
actually presented to it (see the [control-model taxonomy](primitives.md#control-model-taxonomy)).
Anthropic's own internal eval reports tool-selection accuracy degrading once a catalog passes
roughly 30–50 tools, and a modest 5-server / 58-tool setup can burn tens of thousands of tokens on
definitions before any real work starts. Those are one vendor's measurements, not a spec claim, but
they're the concrete reason this problem exists at all.

**The three places filtering can actually happen**, since the protocol itself doesn't provide it:

| Locus | Mechanism | Real examples |
| --- | --- | --- |
| Server/gateway-side | A wrapping server exposes a small meta-tool set (`search_tools`, `describe_tool`, `execute_tool`) and hides the real catalog behind it | IBM `mcp-context-forge` "virtual meta-server"; `agentic-community/mcp-gateway-registry` (semantic search over registered servers, identity/policy-scoped so an agent only discovers what it's authorized to use) |
| Client-side | The client decides which connected servers'/tools' definitions actually go into a given request — user enables/disables servers, or the client defers definitions until needed | Common practice: pick the handful of servers relevant to a workflow and disable the rest |
| Meta-tool / inference-layer search | The model calls a search tool; a search mechanism (regex/BM25/embeddings) returns references that get expanded into full definitions inline | Anthropic's Tool Search Tool and Claude Code's tool-search default — this is an Anthropic API/host feature, not an MCP mechanism; see the `claude-api` skill for how it actually works (`defer_loading`, `tool_reference` blocks, `ENABLE_TOOL_SEARCH`) rather than duplicating it here |

**Namespacing.** There's no spec-mandated separator for disambiguating same-named tools across
servers — it's host convention. Claude Code, for instance, prefixes MCP tools by server name; don't
assume every host uses the same exact separator or that this is a protocol requirement.

**Writing discoverable tool descriptions** (portable advice, useful regardless of host): use a
consistent naming prefix per server so a single search matches the whole group, put task-oriented
keywords in the description that match how a user would actually phrase a request, and prefer
specific names (`search_slack_messages`) over generic ones (`query_slack`) — generic names collide
and are ambiguous once you're aggregating many servers.

**Gotcha:** if your server frequently adds/removes tools and fires `list_changed` mid-conversation,
be aware that on hosts using prompt caching, changing the tool-definitions prefix busts that cache
for the rest of the conversation — a purely inference-layer cost, but one that server authors
toggling tools dynamically should know about.

## The MCP Registry — discovering which servers exist (currently in preview)

**Status, stated directly on the page:** "currently in preview. Breaking changes or data resets may
occur before general availability." Don't build production dependencies on exact behavior yet.

**What it is:** a centralized *metadata* repository — not a code host. It stores a standardized
`server.json` per server (unique name, where to find it — an npm/PyPI/Docker package or a remote
URL — execution instructions, description/capabilities), backed by Anthropic, GitHub, PulseMCP, and
Microsoft among others.

**Namespace verification:** server names follow a reverse-DNS format (`io.github.user/server-name`,
`com.example/server`) tied to a verified GitHub account or domain via a DNS/GitHub/HTTP challenge —
this is what stops anyone from publishing under a namespace they don't own.

**Consumption model — the commonly-missed part:** the Registry is **not** meant to be consumed
directly by host applications. Hosts are expected to consume downstream *aggregators* (marketplaces
built on top of the Registry's data) via a published OpenAPI REST API spec that both the official
Registry and other (including private/self-hosted) registries can implement. Aggregators are
expected to pull fresh metadata on an infrequent schedule (the docs suggest roughly hourly), not
query the Registry live per-request.

**No private servers.** The official Registry only accepts servers whose install method or
endpoint is publicly reachable. If you need to publish internal/private servers for your org, the
guidance is to self-host your own registry implementing the same OpenAPI interface — the official
Registry's own codebase is explicitly not designed to be self-hosted/supported for that purpose.

**Security posture:** the Registry itself does namespace authentication and spam/abuse prevention
(character limits, validation, manual takedown) — it explicitly delegates actual code security
scanning to the underlying package registries (npm/PyPI/Docker) and to downstream aggregators.
Namespace ownership is not a code-safety guarantee.

## Sources (exact URLs fetched, July 2026)

- https://modelcontextprotocol.io/specification/2025-11-25/server/tools (confirms no search/filter param beyond `cursor`)
- https://www.anthropic.com/engineering/advanced-tool-use — Anthropic's own tool-selection-accuracy figures (2025-11-24)
- https://code.claude.com/docs/en/agent-sdk/tool-search — Claude Code's tool-search defaults (`ENABLE_TOOL_SEARCH`) — see `claude-api` skill, not duplicated here
- https://modelcontextprotocol.io/registry/about.md (fetched directly — preview status, server.json, aggregator consumption model, no-private-servers policy, security posture)

Cited for pattern existence, not individually re-fetched: GitHub `IBM/mcp-context-forge` issue
#2230 (virtual meta-server); `agentic-community/mcp-gateway-registry` (semantic-search gateway).

If re-verifying: check whether the Registry has moved from "preview" to general availability at
`/registry/about.md`, and re-check `/specification/<latest-date>/server/tools` in case a
search/filter parameter is ever added to `tools/list` directly.
