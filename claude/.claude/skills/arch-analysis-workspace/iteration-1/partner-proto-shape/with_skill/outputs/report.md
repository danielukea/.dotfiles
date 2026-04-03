# Architectural Analysis: partner-integration-prototype

## Stack & Size

| Dimension | Value |
|-----------|-------|
| Language | JavaScript (ES Modules) |
| Runtime | Node.js |
| Framework | Express 5.2 |
| Dependencies | `express`, `dotenv` (2 production deps) |
| Source files | 9 (excluding node_modules, config, data) |
| Lines of code | ~713 across all JS source |
| Data files | 1 JSON fixture (contacts.json, 106 lines, 4 contacts) |
| Git commits | 17 |
| Test suite | None (`"test": "echo \"Error: no test specified\" && exit 1"`) |
| Purpose | Reference implementation for the Wealthbox AI agent partner plugin webhook contract |

This is a small, intentionally scoped prototype. It exists to validate developer experience (DX) for a webhook-based partner integration system, not to be production infrastructure. The README is arguably the most important artifact.

---

## What's Working Well

- **Extremely low coupling.** Tool handlers are pure functions -- they receive `input`, return `{ status, result }`. Zero dependency on Express, request objects, or middleware. This is excellent for a reference implementation because partners can copy these patterns directly.

- **Clean separation of concerns.** The codebase has three clear layers: server/routing (`server.js`), tool dispatch (`tools/index.js`), and individual tool handlers (`tools/*.js`). Middleware sits in its own directory. A partner developer reading this code can immediately understand where things go.

- **Thoughtful webhook contract design.** Single endpoint with event-based routing, namespace stripping, and a standardized three-status response format (`success`/`not_found`/`error`). The DX_NOTES.md shows this was arrived at deliberately.

- **Developer ergonomics.** Query-param simulation (`?delay_ms`, `?error=timeout|500|not_found`), structured request/response logging, health check endpoint, and a comprehensive Postman collection. These are the kinds of affordances that make prototypes actually usable.

- **OAuth implementation is thorough for a prototype.** Authorization code flow, refresh tokens, token introspection, PKCE-ready patterns, proper timing-safe comparison in signature verification. Code expiry, single-use codes, and redirect URI validation are all present.

- **The README is production-quality documentation.** It covers quickstart, contract details, tool registration, auth flow, response format, and project structure. It reads like something you'd hand to an external developer.

---

## Top Findings (ranked by impact)

### 1. server.js Is a Monolith (519 lines, ~73% of all code)

**Category**: Maintainability & Conventions  |  **Severity**: medium
**Flagged by**: Structure, Coupling, Complexity
**Evidence**: `server.js` is 519 lines containing Express app setup, request logging middleware, error simulation middleware, the webhook handler, 5 OAuth endpoints (authorize page with inline HTML, authorize callback, token exchange, token refresh, token introspection), and the server startup. The OAuth endpoints alone account for ~350 lines, primarily because of inline HTML templates.
**Impact**: As the prototype evolves (the PLAN.md describes adding more event types, connection.test wiring, and async callbacks), this file will become harder to navigate. More critically, a partner developer looking at server.js as a reference sees OAuth complexity they don't need to understand for the webhook contract.
**Direction**: Extract OAuth routes into `routes/oauth.js` and move inline HTML into template files or a `views/` directory. This also makes the "core webhook contract" code (~50 lines) more visible to partners reading the source.

### 2. XSS Vulnerability in OAuth HTML Templates

**Category**: Reliability & Error Handling  |  **Severity**: high
**Flagged by**: Error Handling, Structure
**Evidence**: `server.js` lines 108, 112, 131, 135, 334-337 interpolate user-controlled query parameters (`error`, `error_description`, `code`, `client_id`, `redirect_uri`, `state`, `scope`) directly into HTML via template literals:
```js
<p style="...">${error}: ${error_description || 'Unknown error'}</p>
window.opener.postMessage({ type: 'oauth_test_callback', error: '${error}' }, '*');
<input type="hidden" name="client_id" value="${client_id}" />
```
A crafted `error_description` or `state` parameter containing `<script>` tags would execute in the browser. The `postMessage` interpolation with `'*'` origin is also exploitable.
**Impact**: In a prototype behind localhost this is low-risk, but this code is meant to be copied by partners. If partners use this pattern in production, they inherit the vulnerability. A reference implementation should model safe patterns.
**Direction**: HTML-escape all interpolated values before rendering. Even in a prototype, use a minimal template function or `encodeURIComponent`/entity-escape utility. Consider noting in the README that the OAuth pages are for local dev only.

### 3. No Error Boundaries Around Tool Execution

**Category**: Reliability & Error Handling  |  **Severity**: medium
**Flagged by**: Error Handling, State
**Evidence**: In `server.js` line 157, `routeTool(tool_name, input)` is called synchronously with no try/catch:
```js
const result = routeTool(tool_name, input);
return res.json(result);
```
In `tools/index.js`, `handler(input)` is called without error handling. Tool handlers (e.g., `get_risk_profile.js`) destructure input directly (`{ contact_email }`) -- if `input` is `null` or missing `contact_email`, the destructure throws. Only `search_clients.js` validates its input.
**Impact**: A malformed webhook payload or a tool handler that throws an unhandled exception would crash the Express process (or return an unstructured 500 in Express 5). Partners copying this pattern would have the same fragility.
**Direction**: Wrap `routeTool` in try/catch and return `{ status: "error", message: "..." }`. Add a defensive `input || {}` fallback in tool handlers. This is also a good pattern to model for partners.

### 4. In-Memory State Has No Cleanup

**Category**: State & Data Flow  |  **Severity**: low
**Flagged by**: State, Complexity
**Evidence**: `server.js` lines 16-18 define three `Map` objects for OAuth state:
```js
const authCodes = new Map();
const accessTokens = new Map();
const refreshTokens = new Map();
```
Expired codes and tokens are only cleaned up when they happen to be accessed. If codes expire without being redeemed (e.g., user closes the authorize page), they remain in memory forever. Refresh tokens are never expired.
**Impact**: In a prototype running locally, this is a non-issue. But as a reference implementation, partners might copy this in-memory token store pattern. If a partner runs this for weeks during development, Maps would grow unbounded.
**Direction**: Add a comment noting this is prototype-only storage. Optionally, add a setInterval cleanup or note that production should use a database with TTL.

### 5. Tool Handlers Load Data at Module Import Time

**Category**: State & Data Flow  |  **Severity**: low
**Flagged by**: State, Coupling
**Evidence**: Every tool handler (get_risk_profile.js, get_portfolio_overview.js, etc.) reads `contacts.json` via top-level `await`:
```js
const contacts = JSON.parse(await readFile(new URL('../data/contacts.json', import.meta.url)));
```
This happens once at import time. The data is effectively a global constant.
**Impact**: This is fine for a fixture-based prototype. However, if a partner later switches to a real database or API, the pattern of "load everything at startup" doesn't translate. More practically, changes to `contacts.json` require a server restart.
**Direction**: This is acceptable as-is for the prototype. Consider noting in comments that production tools would call a database/API per-request.

### 6. QA.md References Stale Tool Names and Namespace

**Category**: Maintainability & Conventions  |  **Severity**: low
**Flagged by**: Structure, Conventions
**Evidence**: `QA.md` references `riskalyze__get_risk_score`, `riskalyze__enrich_contact`, `riskalyze__get_plan_summary` (the old namespace and tool names). The actual codebase uses namespace `vantage` with tools: `get_risk_profile`, `get_portfolio_overview`, `get_meeting_prep`, `get_document_checklist`, `search_clients`, `echo`. Similarly, PLAN.md references the old `riskalyze` namespace throughout.
**Impact**: A developer trying to QA the prototype using QA.md would hit "Unknown tool" errors immediately. The disconnect between documentation and code creates confusion.
**Direction**: Update QA.md to match the current `vantage` namespace and tool names. PLAN.md is historical context so it's less critical, but adding a note at the top that the namespace changed from riskalyze to vantage would help.

---

## Lower Priority

**Maintainability & Conventions**
- The `echo` tool is registered in `tools/index.js` but not declared in `seed.json`. It's a debug utility, which is fine, but the asymmetry could confuse a partner comparing the two files.
- No `.prettierrc`, `.eslintrc`, or formatting config. For a reference implementation, consistent code style matters since partners will copy it.
- The `partner-integration-prototype` directory name doesn't match the `package.json` name (`vantage-partner-integration`) or the README title ("Wealthbox Plugin -- Partner Integration Reference") or the directory referenced in PLAN.md (`partner-integration-reference`). Four different names for the same thing.

**Architecture & Coupling**
- The signature verification middleware reads `req.rawBody` which is set by the JSON body parser's `verify` callback in server.js. This couples the middleware to a specific body-parser configuration. A comment in `verify-signature.js` explains the fallback, but it's a subtle dependency.

**Data Integrity**
- The Postman collections in `postman/` were not examined for staleness, but given the QA.md drift, they likely reference old tool names too.

---

## Metrics Summary

| Metric | Value |
|--------|-------|
| Total source files | 9 |
| Total lines of code | 713 |
| Largest file | server.js (519 lines, 73% of codebase) |
| Production dependencies | 2 (express, dotenv) |
| Tool handlers | 6 (5 domain + 1 debug echo) |
| Fixture contacts | 4 |
| Git commits | 17 |
| Test coverage | 0% (no test suite exists) |
| CLI tools available | rubocop, brakeman (Ruby -- not applicable to this JS project) |
| Duplication analysis | Skipped (< 20 source files) |
| Churn analysis | Skipped (< 50 commits) |

---

## Overall Shape Summary

This is a well-structured, small prototype that does exactly what it set out to do: validate the developer experience of the Wealthbox partner integration webhook contract. The code is clean, the separation between tools and routing is good, and the documentation (README, PLAN.md, DX_NOTES.md) is unusually thorough for a prototype.

The main structural tension is that `server.js` serves two audiences -- it's both the webhook reference implementation AND a full OAuth server -- and those concerns are mixed in a single 519-line file. The webhook contract portion (~50 lines of actual routing logic) is excellent. The OAuth portion is thorough but dominates the file and introduces the only security concern (HTML template injection).

For a prototype, the codebase is in good shape. The highest-value improvements would be: (1) wrapping tool execution in try/catch for safety, (2) escaping HTML in OAuth templates, and (3) updating QA.md to match the current namespace/tools. Everything else is refinement.
