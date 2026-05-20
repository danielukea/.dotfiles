# OWASP Top 10 2025 + API Security Top 10 2023

Quick reference for security agents. Each entry: category, what to look for in code, prevention pattern.

---

## OWASP Web Application Top 10 (2025)

### A01 — Broken Access Control

**What to look for:**
- Missing authorization checks before returning/modifying resources
- Direct object references using user-controlled IDs without ownership verification
- Regular users able to reach admin-only routes or actions
- Horizontal privilege escalation (user A accessing user B's data)
- Missing `before_action :authorize!` or equivalent guards

**Prevention:** Check ownership/permission on every resource access, not just at route level. Deny by default.

---

### A02 — Security Misconfiguration

**What to look for:**
- Default credentials, hardcoded API keys, secrets in source
- Debug mode enabled in production (`config.debug_exception_response_format`, `React DevTools` in prod bundles)
- Unnecessary endpoints exposed (`/rails/info`, Swagger UI in prod)
- Missing security headers (CSP, X-Frame-Options, HSTS, X-Content-Type-Options)
- Permissive CORS (`Access-Control-Allow-Origin: *` on authenticated APIs)
- Stack traces or verbose errors returned to clients

**Prevention:** Security hardening checklists, environment-specific config, remove debug features before deploy.

---

### A03 — Software Supply Chain Failures

**What to look for:**
- Dependencies with known CVEs (`bundle audit`, `npm audit`, `yarn audit`)
- Outdated lock files or unpinned dependency ranges (`^`, `~`, `*`)
- `eval()` of externally-sourced code
- Direct `require` of URLs or remote content

**Prevention:** Dependency scanning in CI, pin versions, verify package integrity.

---

### A04 — Cryptographic Failures

**What to look for:**
- Passwords hashed with MD5, SHA1, SHA256 (not bcrypt/Argon2/scrypt)
- Sensitive data (SSN, CC numbers, tokens) stored in plaintext or weak encryption
- HTTP instead of HTTPS for sensitive transmissions
- Hardcoded encryption keys or IVs
- Weak random number generation (`rand`, `Math.random()` for security tokens)
- JWT with `alg: none` or weak secrets

**Prevention:** bcrypt/Argon2 for passwords, AES-256 for data at rest, TLS everywhere, `SecureRandom` for tokens.

---

### A05 — Injection

**What to look for:**
- String interpolation in SQL: `"WHERE id = #{params[:id]}"`, `.where("name = '#{name}'")`
- `system()`, `exec()`, backticks with user input
- `eval()` with user-controlled strings
- LDAP/XPath queries built from user input
- Template injection (`ERB.new(user_input).result`)
- `render inline: params[:template]`

**Prevention:** Parameterized queries, allowlists, never pass user input to interpreters.

---

### A06 — Insecure Design

**What to look for:**
- No rate limiting on login, password reset, or sensitive endpoints
- No account lockout after repeated failures
- Business logic skippable via direct URL access
- Missing multi-step verification for irreversible operations (delete, transfer)
- Predictable tokens or IDs for sensitive operations

**Prevention:** Threat model during design, rate limiting, multi-factor for critical actions.

---

### A07 — Authentication Failures

**What to look for:**
- Session not invalidated on logout (`reset_session` missing)
- Session not regenerated after login (session fixation risk)
- Weak or short-lived-token-less password reset flows
- No brute force protection on login/reset endpoints
- Tokens in query params (logged in server logs, browser history)
- Passwords logged in plaintext
- Missing MFA on admin or privileged accounts

**Prevention:** `reset_session` on login/logout, rate limit auth endpoints, secure token delivery.

---

### A08 — Software & Data Integrity Failures

**What to look for:**
- Deserialization of untrusted data (`Marshal.load`, `YAML.load` without safe mode, `JSON.parse` fed to `eval`)
- CI/CD pipeline with unauthenticated write access
- Auto-update mechanisms without signature verification
- `.send(params[:method])` or similar dynamic dispatch on user input

**Prevention:** Use `JSON.parse` not `eval`, `YAML.safe_load`, never `Marshal.load` untrusted data.

---

### A09 — Security Logging & Alerting Failures

**What to look for:**
- Auth events (login, logout, failed login, password reset) not logged
- Privilege escalation events not recorded
- Logs containing sensitive data (passwords, tokens, PII)
- No monitoring/alerting on repeated failures
- Logs writable/deletable by application user

**Prevention:** Log security events with user ID + IP + timestamp, protect logs, alert on anomalies.

---

### A10 — Mishandling of Exceptional Conditions

**What to look for:**
- `rescue Exception` (catches everything including system signals)
- Exceptions swallowed silently (`rescue nil` or empty rescue blocks)
- Stack traces or internal paths returned to API clients
- Partial state left on exception (transaction not rolled back)
- Errors revealing framework version, DB type, or file paths

**Prevention:** Generic error messages to users, detailed logging server-side, fail-closed.

---

## OWASP API Security Top 10 (2023)

### API1 — Broken Object Level Authorization (BOLA / IDOR)

Every API endpoint that returns or modifies a resource must verify the requesting user owns/can access that specific object. Checking at the route level only is insufficient.

**Signs:** `User.find(params[:id])` without `.where(account: current_account)`.

---

### API2 — Broken Authentication

Token validation on every request, not just login. Short-lived tokens. No tokens in URLs.

**Signs:** JWTs not validated server-side, no expiry check, tokens in query params.

---

### API3 — Broken Object Property Level Authorization

API returning more fields than the user should see (mass exposure), or accepting more fields than intended (mass assignment).

**Signs:** `render json: @user` (dumps all columns), `User.new(params[:user])` without strong params.

---

### API4 — Unrestricted Resource Consumption

No pagination defaults, no request size limits, no rate limiting on expensive operations.

**Signs:** `User.all` without pagination, no `max_per_page`, no rate limiting middleware.

---

### API5 — Broken Function Level Authorization

Users accessing functions/endpoints meant for admins or other roles.

**Signs:** Admin endpoints without role check, HTTP verbs not restricted (DELETE open to all).

---

### API6 — Unrestricted Access to Sensitive Business Flows

Automatable flows without abuse prevention: mass account creation, automated purchases, bulk password reset.

**Signs:** No CAPTCHA, no rate limit, no anomaly detection on critical business operations.

---

### API7 — Server Side Request Forgery (SSRF)

API fetching a URL provided by the user without validation — can reach internal services, AWS metadata (169.254.169.254), localhost.

**Signs:** `Net::HTTP.get(URI(params[:url]))`, `open(params[:url])`, `RestClient.get(user_url)`.

---

### API8 — Security Misconfiguration

Same as A02 but API-specific: permissive CORS, debug endpoints, default API keys, no TLS.

---

### API9 — Improper Inventory Management

Deprecated API versions still accessible, undocumented internal endpoints, staging APIs reachable from prod.

**Signs:** `/api/v1/` still live alongside `/api/v3/`, undocumented `/internal/` routes.

---

### API10 — Unsafe Consumption of APIs

Third-party API responses treated as trusted — no validation, used directly in queries or templates.

**Signs:** `query = third_party_response['name']` used in SQL, no sanitization of external data.
