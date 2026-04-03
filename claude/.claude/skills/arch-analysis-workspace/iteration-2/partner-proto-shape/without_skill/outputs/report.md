# Partner Integration Prototype - Architecture Report

## What It Is

A reference implementation for the Wealthbox AI agent plugin system, branded as "Vantage Client Intelligence." It is a Node.js/Express server that a third-party partner would clone and adapt to expose their tools (risk profiles, portfolio data, meeting prep, etc.) to the Wealthbox AI agent via webhooks.

The project implements Milestones 1-3 of a larger roadmap for an inbound plugin framework (Project 2 from a CPO spec). DX quality is the explicit priority — if a partner developer can't go from the README to a working endpoint quickly, the contract is wrong.

## Size and Composition

| Language   | Files | Code Lines |
|------------|-------|------------|
| JavaScript | 9     | 576        |
| JSON       | 7     | 2,100      |
| Markdown   | 6     | 2,404      |
| HTML       | 2     | 129        |
| **Total**  | **24**| **5,209**  |

This is a small, documentation-heavy prototype. The markdown (README, PLAN, QA, DX_NOTES) outweighs the code, which is intentional — the README **is** the primary artifact that defines the webhook contract.

## Architecture

### Single-file server (`server.js`, ~520 lines)

The entire application is one Express server with three concerns mixed into a single file:

1. **Webhook endpoint** (`POST /webhook`) - Single entry point for all tool invocations. Routes by an `event` field in the JSON body (`tool.invoke`, `connection.test`). Signature verification via middleware.

2. **OAuth 2.0 provider** - Full authorization code flow with authorize page, token exchange, refresh, and introspection. Uses in-memory Maps for auth codes, access tokens, and refresh tokens. Renders inline HTML for the authorize/callback pages.

3. **Development helpers** - Simulated latency (`?delay_ms=2000`), simulated errors (`?error=500`, `?error=timeout`), and structured request/response logging middleware.

### Tool system (`tools/`)

Six tool handlers, each a pure function: `input -> response object`. All follow the same pattern:
- Load `data/contacts.json` at module level
- Look up a contact by email (or search by query)
- Return `{ status: "success", result: {...} }` or `{ status: "not_found", message: "..." }`

Tools registered:
- `get_risk_profile` - Risk score, tolerance, KYC, compliance flags
- `get_portfolio_overview` - Portfolio value, YTD return, allocation, holdings
- `get_meeting_prep` - Next meeting, talking points, recent activity, action items
- `get_document_checklist` - Completed/pending documents, deadlines
- `search_clients` - Name/email search across contacts
- `echo` - Debug/test tool

The router (`tools/index.js`) strips namespace prefixes (e.g., `vantage__get_risk_profile` -> `get_risk_profile`) before dispatching.

### Data layer (`data/contacts.json`)

Static fixture data. A JSON array of contact objects with nested structures for portfolio, meeting, and document data. No database, no external API calls — everything is in-memory from this one file.

### Middleware (`middleware/verify-signature.js`)

HMAC-SHA256 signature verification using `X-Wealthbox-Signature` and `X-Wealthbox-Timestamp` headers. Uses timing-safe comparison. Skips verification when `WEBHOOK_SECRET` is unset (dev convenience).

### Plugin manifest (`seed.json`)

Declares the plugin namespace (`vantage`), display name, webhook URL, and all 5 tool definitions with JSON Schema parameters. This is what gets uploaded to Wealthbox to register the plugin.

## Key Design Decisions

1. **Single webhook endpoint, event-based routing** - Partners configure one URL, not one per tool. The `event` field determines behavior. This simplifies registration and deployment.

2. **Always HTTP 200** - Errors are communicated via `status` field in the response body (`success`, `not_found`, `error`), never via HTTP status codes. The agent uses the status to decide how to proceed.

3. **Namespaced tools** - Tool names are prefixed with the partner namespace (`vantage__get_risk_profile`). The server strips the prefix before routing, so handler code only deals with bare names.

4. **Custom protocol, not MCP** - This is deliberately not Model Context Protocol or another standard. The CPO spec calls this out as intentional lock-in — partners build specifically for Wealthbox.

5. **Sync only** - The CPO spec includes async callback support, but this prototype defers it. All tool invocations are synchronous request/response.

6. **OAuth as the partner, not the consumer** - The server acts as an OAuth provider (Vantage authorizes Wealthbox), not a consumer. This models the "firm linking" flow where an advisor authorizes the connection between their Wealthbox account and their Vantage account.

## Dependencies

Minimal: just `express` (v5.2) and `dotenv`. No test framework, no build step, no TypeScript. Pure ES modules (`"type": "module"`).

## What's Missing (by design)

- No tests (`npm test` exits with error)
- No database or persistence (in-memory Maps, static JSON fixtures)
- No production auth (OAuth uses hardcoded client ID/secret)
- No async tool support
- No rate limiting or request validation beyond signature check
- No deployment configuration

These are all intentional for a prototype whose purpose is to validate the developer experience of the webhook contract.

## Supporting Artifacts

- `postman/` - Two Postman collections (one for the tool API, one for a mock server)
- `docs/` - Contains a `superpowers/` subdirectory (likely Claude Code skill docs)
- `PLAN.md` - Detailed implementation plan with CPO spec alignment
- `QA.md` - QA testing documentation
- `DX_NOTES.md` - Developer experience observations
- `vantage-oauth-authorize.png` - Screenshot of the OAuth authorization page
