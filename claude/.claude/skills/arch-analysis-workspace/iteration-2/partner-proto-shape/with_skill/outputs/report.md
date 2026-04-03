# Architectural Analysis: partner-integration-prototype

## Stack & Size

| Dimension | Value |
|-----------|-------|
| **Stack** | Node.js (ES modules) + Express 5 |
| **Dependencies** | 2 (express, dotenv) — extremely minimal |
| **Source files** | 9 JavaScript files |
| **Lines of code** | 576 (JS only) |
| **Total complexity** | 50 (scc) — 72% concentrated in server.js |
| **Git commits** | 17 |
| **Data files** | 1 JSON fixture (contacts.json, 4 records) |
| **Purpose** | Reference implementation for the Wealthbox AI agent partner plugin system (webhook-based tool invocation + OAuth 2.0 firm linking) |

### CLI Tools Used
- **scc**: Code stats and per-file complexity
- **jscpd**: Duplication detection (found 3 clone clusters in tool handlers)
- **ast-grep**: Structural pattern searches (no try/catch blocks, no process.exit calls found)
- **dep-tree**: Attempted entropy check (not enough files to analyze)

---

## What's Working Well

- **Extremely focused scope.** Two dependencies, 576 lines of JS. This is a prototype that knows it's a prototype — no framework bloat, no over-engineering.

- **Clean separation of concerns.** The three-layer structure (server.js -> tools/index.js -> individual tool handlers) is clear and immediately understandable. A partner developer can grasp the architecture from the directory listing alone.

- **Well-designed webhook contract.** Single endpoint with event-based routing, namespace-stripping for tool names, and a consistent three-status response format (success/not_found/error). This is developer-friendly.

- **Good security defaults.** HMAC-SHA256 signature verification with timing-safe comparison, raw body capture for accurate signing, and a clear dev-mode bypass with a warning log. The OAuth implementation covers the full authorization code + refresh token flow.

- **Excellent README.** The README doubles as a developer guide — quickstart, webhook contract, tool registration, OAuth flow, project structure. It reads like something a partner developer could actually use.

- **Testing affordances built in.** Delay simulation (`?delay_ms=`), error simulation (`?error=500/not_found/timeout`), echo tool, and Postman collections included. These are DX features that most prototypes skip.

---

## Top Findings (ranked by impact)

### 1. server.js is a monolith — OAuth, routing, middleware, and HTML templates in one file
**Category**: Structure & Conventions  |  **Severity**: medium
**Flagged by**: Structure, Complexity, Coupling
**Evidence**: `server.js` is 519 lines with complexity score 36 (72% of total codebase complexity). It contains: Express app setup, request logging middleware, test simulation middleware, health endpoint, OAuth authorization page (with full inline HTML/CSS — 130 lines), OAuth callback handler, OAuth token exchange, token introspection, webhook routing, and in-memory token stores.
**Impact**: As the prototype grows to cover more OAuth scenarios, additional event types, or UI pages, this file will become the dominant hotspot. It already has the highest churn (9 commits touching it). For a reference implementation, this matters extra — partners will model their code on this structure.
**Direction**: Extract OAuth endpoints into `routes/oauth.js`, move HTML templates to separate files or a minimal template function, and extract the in-memory token store into `auth/store.js`. The webhook handler can stay in server.js since it's the core purpose.

### 2. Tool handlers are copy-paste clones with identical boilerplate
**Category**: Duplication & Patterns  |  **Severity**: medium
**Flagged by**: Duplication (jscpd), Structure
**Evidence**: jscpd found 3 clone clusters across tool handlers. Every tool handler (get_risk_profile, get_portfolio_overview, get_meeting_prep, get_document_checklist) follows the exact same pattern:
```
import contacts from JSON
find contact by email
if (!contact) return not_found
return { status: 'success', result: { name, email, ...contact.X } }
```
The contact lookup + not_found check is duplicated 4 times verbatim (12 lines each clone).
**Impact**: Low for a 4-tool prototype, but the README instructs partners to copy this pattern for every new tool. If a partner builds 20 tools that all do contact lookups, a bug in the lookup logic means fixing 20 files. The example sets the wrong precedent.
**Direction**: Extract a `withContact(contact_email, fn)` helper that handles lookup and not_found, so tool handlers only define the response mapping. This also models better DX for partners: show them that shared patterns should be extracted.

### 3. No error handling in tool execution path
**Category**: Error Handling & Resilience  |  **Severity**: medium
**Flagged by**: Error Handling, State
**Evidence**: ast-grep found zero try/catch blocks in the entire codebase. The webhook handler in server.js calls `routeTool(tool_name, input)` with no error boundary:
```js
const result = routeTool(tool_name, input);
return res.json(result);
```
If a tool handler throws (e.g., contacts.json fails to load, input is null, a tool does async work that rejects), the Express default error handler returns a 500 with a stack trace.
**Impact**: For the prototype's current synchronous-with-static-data tools, this rarely triggers. But partners copying this pattern will build tools that call external APIs, databases, etc. — and those will throw. The reference should model resilient patterns.
**Direction**: Wrap `routeTool` in try/catch that returns `{ status: 'error', message: '...' }`. Also consider making `routeTool` async-aware since real tools will be async.

### 4. OAuth state stored in-memory Maps with no eviction
**Category**: State & Data Flow  |  **Severity**: low
**Flagged by**: State
**Evidence**: Three `new Map()` instances at module scope: `authCodes`, `accessTokens`, `refreshTokens`. Auth codes expire after 60 seconds and get deleted on use, but expired-but-unused codes are never cleaned up. Access tokens expire after 1 hour but are only deleted on refresh or introspection — not proactively. Refresh tokens never expire.
**Impact**: Minimal for a prototype that restarts frequently. But it's worth noting in the README that production implementations need a real store with TTL eviction. Partners may copy the pattern.
**Direction**: Add a comment in server.js noting this is dev-only. Optionally add a setInterval sweep for expired tokens, but a README note is sufficient for a reference implementation.

### 5. Inline HTML templates create XSS surface in OAuth pages
**Category**: Error Handling & Resilience  |  **Severity**: low
**Flagged by**: Error Handling, Structure
**Evidence**: The OAuth authorize page and callbacks use template literals to inject query parameters directly into HTML:
- `server.js:105`: `${error}` and `${error_description}` injected unescaped into HTML body and JavaScript
- `server.js:131`: `${code}` injected into HTML and postMessage
- `server.js:338`: `${state}`, `${scope}`, `${client_id}` injected into hidden form fields
**Impact**: In a prototype context, this is low risk since inputs come from controlled sources (Wealthbox). But the pattern is unsafe to copy for production. A partner adapting this code with user-controlled query params would have an XSS vulnerability.
**Direction**: Add a simple `escapeHtml()` utility and apply it to all template interpolations in HTML contexts. Alternatively, note in the README that production OAuth pages should use a template engine.

---

## Lower Priority

**Maintainability & Conventions**
- Tool file names use different conventions than tool registry names: files are `get_risk_profile.js` but the old tool names in git history were `get_risk_score.js`, `enrich_contact.js` — tools were renamed during a rebrand. No broken references remain, but the git history shows a full tool-set replacement in one commit.
- The `echo.js` tool is undocumented in `seed.json` — it exists as a dev utility but wouldn't be registered with Wealthbox. Consider moving it to a `dev-tools/` directory to signal this.
- `search_clients.js` takes a `query` parameter instead of `contact_email`, breaking the pattern of the other tools. This is intentional (search needs different input), but could be confusing if a partner expects consistency.

**Data Integrity**
- Each tool handler independently reads and parses `contacts.json` at module load time via top-level `await`. If the file is missing or malformed, the import fails at startup with an unhandled rejection. This is actually fine for a prototype (fail fast), but differs from how the README describes error handling.
- No input validation on `contact_email` — tools accept any string (empty, undefined, non-email format). For a reference implementation, showing basic validation would be educational.

---

## Metrics Summary

| Metric | Value | Interpretation |
|--------|-------|----------------|
| **Total JS complexity** (scc) | 50 | Low overall — appropriate for a prototype |
| **server.js complexity** | 36 | 72% of total — concentration risk as it grows |
| **Duplication** (jscpd) | 3 clone clusters, 4 files | Tool handlers are structurally identical |
| **Highest churn file** | server.js (9/17 commits) | Expected for a monolithic entry point |
| **Try/catch blocks** | 0 | No error boundaries in application code |
| **Dependencies** | 2 (express, dotenv) | Minimal — good for a reference implementation |
| **Test coverage** | None | `npm test` exits with error — no test suite exists |
| **Tool handlers** | 6 (5 real + 1 echo) | Clean registry pattern |
