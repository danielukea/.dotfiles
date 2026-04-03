# Partner Integration Prototype - Architecture Report

## What This Is

A **reference implementation** for a third-party partner plugin system for the Wealthbox CRM AI agent. The fictional partner is "Vantage Client Intelligence" -- a wealth management data provider. The repo demonstrates what a partner developer would build to integrate their tools into Wealthbox's AI chat.

This is **not** a production system. It is a DX (developer experience) prototype that drives the design of the real webhook contract, auth flow, and registration process. The guiding principle: if a partner developer can't go from the README to a working endpoint quickly, the contract is wrong.

## Tech Stack

- **Runtime:** Node.js (ES modules)
- **Framework:** Express 5
- **Dependencies:** Only `express` and `dotenv` -- intentionally minimal
- **No database** -- all data is in-memory (JSON fixtures, Map-based token stores)
- **No tests** -- prototype-only, validated via Postman collections and manual QA

## Project Structure

```
partner-integration-prototype/
  server.js              # Single Express app (~520 lines): routes, middleware, full OAuth server
  seed.json              # Plugin manifest declaring namespace + 5 tools with JSON Schema params
  data/
    contacts.json        # Fixture data for 4 fake clients (risk, portfolio, meetings, docs)
  tools/
    index.js             # Tool registry + router (strips namespace prefix, dispatches to handler)
    get_risk_profile.js  # Risk score, KYC status, compliance flags
    get_portfolio_overview.js  # Portfolio value, YTD return, asset allocation, holdings
    get_meeting_prep.js  # Upcoming meeting context, talking points, action items
    get_document_checklist.js  # Document completion status, pending items, deadlines
    search_clients.js    # Search by name or email
    echo.js              # Debug/testing passthrough tool
  middleware/
    verify-signature.js  # HMAC-SHA256 signature verification (X-Wealthbox-Signature)
  postman/               # Two Postman collections for manual testing
  docs/                  # Supplementary docs
```

Total source code: ~713 lines across 9 files. Very small, very focused.

## Architecture Shape

### Single Webhook Endpoint

Everything flows through `POST /webhook`. The `event` field in the JSON body determines what happens:

- `tool.invoke` -- the AI agent is calling a partner tool; dispatches to a handler by `tool_name`
- `connection.test` -- health check from Wealthbox

Tool names are namespaced (`vantage__get_risk_profile`). The router strips the namespace prefix before dispatching, so handlers only deal with bare names.

### Tool Handler Pattern

Each tool is a pure function: receives `input` object, returns a response object with one of three statuses:

- `{ status: "success", result: { ... } }` -- data returned
- `{ status: "not_found", message: "..." }` -- resource doesn't exist (not an error)
- `{ status: "error", message: "..." }` -- something went wrong

All tools use the same fixture data (`data/contacts.json`) and look up clients by email. The data is rich enough to be realistic: risk scores, portfolio allocations, meeting agendas, document checklists.

### Security Layer

- **HMAC-SHA256 signature verification** via `X-Wealthbox-Signature` header. Uses `timestamp.body` as the signed payload with timing-safe comparison. Skipped if `WEBHOOK_SECRET` is unset (dev convenience).
- **Full OAuth 2.0 authorization code flow** for firm-level account linking. Includes `/oauth/authorize` (branded consent page), `/oauth/authorize/callback`, `/oauth/token` (code exchange + refresh), and `/oauth/token/info` (introspection). All in-memory, no persistence.

### Developer Ergonomics

Built into the webhook middleware:

- `?delay_ms=N` -- simulates latency
- `?error=500|not_found|timeout` -- simulates failure modes (timeout hangs forever)
- Structured JSON request/response logging on every call
- `GET /health` endpoint with tool count

## Relationship to the Larger System

This repo is one half of a two-repo prototype:

| Repo | Role |
|------|------|
| **This repo** (partner-integration-prototype) | What a partner builds -- webhook server, tools, OAuth provider |
| **crm-web** (Wealthbox Rails app, separate worktree) | What the platform provides -- tool registry, agent orchestration, dev portal, firm enablement UI |

The `PLAN.md` describes the full build order: Phase A builds this Node server and README first, Phase B updates crm-web to match the contract this server defines, Phase C validates end-to-end.

The `seed.json` serves dual purpose: it is the tool registration manifest a partner would upload to the Wealthbox developer portal, and it seeds the `Composer::PartnerTool` records in crm-web.

## Key Design Decisions

1. **Custom protocol, not MCP** -- intentional lock-in per CPO spec. Partners build specifically for Wealthbox.
2. **Single endpoint, event-based routing** -- partners configure one URL; the `event` field determines behavior. Future events arrive at the same endpoint.
3. **Always HTTP 200** -- errors are expressed in the response body `status` field, never via HTTP status codes.
4. **Namespace prefix on tool names** -- enables multiple partners to register tools without name collisions; gives the LLM context about tool provenance.
5. **Sync only** -- async/callback pattern deferred to later milestone.
6. **DX drives the contract** -- the plan explicitly states that if something feels awkward while building the Node server, the contract should change.

## Maturity / Status

The git history shows 17 commits of focused incremental work. The `DX_NOTES.md` captures friction observations. The `QA.md` has a comprehensive test plan covering the Node server standalone, crm-web models, developer portal API, and end-to-end AI chat integration -- most items appear unchecked, suggesting QA is in progress or pending.

The prototype covers Milestones 1-3 from the production roadmap: first real partner live, firm self-service connect/disconnect, and partner self-service register/test.
