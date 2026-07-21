# OWASP Top 10 2025 + API Security Top 10 2023

A taxonomy and compliance index. Each category: the question it asks, the named
attacks that fall under it (detailed in [attacks.md](attacks.md)), and the
generic prevention principle. Framework-specific code lives in the stack adapters
(`stacks/rails.md`, `stacks/react.md`).

---

## OWASP Web Application Top 10 (2025)

### A01 — Broken Access Control
**Asks:** is every resource access scoped to its owner, not just gated at the route?
**Attacks:** IDOR/BOLA, CSRF, path traversal, open redirect.
**Prevention:** authorize each object (not just the route); deny by default.

### A02 — Security Misconfiguration
**Asks:** are defaults hardened, secrets kept out of source, headers/CORS set, debug off?
**Attacks:** clickjacking, missing CSP, tokens in web storage, directory listing.
**Prevention:** a hardening baseline, environment-specific config, remove debug features before deploy.

### A03 — Software Supply Chain Failures
**Asks:** are dependencies pinned, scanned, and integrity-verified?
**Prevention:** dependency scanning in CI, pinned versions, verified package integrity; no `eval`/`require` of remote code.

### A04 — Cryptographic Failures
**Asks:** are passwords hashed with a slow KDF, secrets encrypted, TLS enforced, randomness cryptographic?
**Prevention:** bcrypt/Argon2/scrypt for passwords, authenticated encryption for data at rest, TLS everywhere, a CSPRNG for tokens; no `alg:none` JWTs.

### A05 — Injection
**Asks:** does untrusted data reach an interpreter (query, shell, template, parser) unparameterized?
**Attacks:** SQL injection, command injection, template injection (SSTI), XSS (stored/reflected/DOM), XXE, HTTP header injection.
**Prevention:** parameterize/bind, allowlist, and never pass user input to an interpreter as code.

### A06 — Insecure Design
**Asks:** are abuse cases designed against — rate limits, lockouts, multi-step verification for irreversible actions?
**Attacks:** credential stuffing/brute force, ReDoS.
**Prevention:** threat-model during design; rate limiting; MFA/confirmation for critical actions.

### A07 — Authentication Failures
**Asks:** is the session invalidated/regenerated at the right moments, are tokens random and short-lived?
**Attacks:** session fixation, session hijacking, credential stuffing, insecure password reset.
**Prevention:** regenerate session on login and clear on logout, rate-limit auth endpoints, deliver tokens securely.

### A08 — Software & Data Integrity Failures
**Asks:** is untrusted data deserialized, or code/updates run without integrity verification?
**Attacks:** insecure deserialization, mass assignment, prototype pollution.
**Prevention:** safe parsers (never native deserialization of untrusted data), signature verification, explicit field allowlists.

### A09 — Security Logging & Alerting Failures
**Asks:** are security events logged (without leaking secrets), and are anomalies alerted on?
**Prevention:** log auth events with principal + IP + timestamp, keep secrets/PII out of logs, protect logs, alert on repeated failures.

### A10 — Mishandling of Exceptional Conditions
**Asks:** do errors fail closed, roll back partial state, and avoid leaking internals?
**Prevention:** catch narrowly (never swallow), generic error messages to clients with detail logged server-side, roll back on failure.

---

## OWASP API Security Top 10 (2023)

### API1 — Broken Object Level Authorization (BOLA / IDOR)
Every endpoint returning or modifying a resource must verify the caller can access that specific object. Route-level checks are insufficient. *(See IDOR in [attacks.md](attacks.md).)*

### API2 — Broken Authentication
Validate tokens on every request, not just at login. Short-lived tokens; no tokens in URLs.

### API3 — Broken Object Property Level Authorization
Returning more fields than the caller should see (mass exposure), or accepting more than intended (mass assignment). Serialize an explicit field set; bind an allowlist.

### API4 — Unrestricted Resource Consumption
Enforce pagination defaults, request-size limits, and rate limits on expensive operations.

### API5 — Broken Function Level Authorization
Restrict admin/role functions and HTTP verbs by role — not just by hiding the route.

### API6 — Unrestricted Access to Sensitive Business Flows
Add abuse prevention (rate limits, CAPTCHA, anomaly detection) to automatable flows: mass signup, bulk purchase, bulk reset.

### API7 — Server Side Request Forgery (SSRF)
Validate any user-supplied URL the server fetches; block private/link-local ranges. *(See SSRF in [attacks.md](attacks.md).)*

### API8 — Security Misconfiguration
API-specific A02: permissive CORS, debug endpoints, default keys, missing TLS.

### API9 — Improper Inventory Management
Retire deprecated versions and undocumented/internal endpoints; keep staging APIs off production.

### API10 — Unsafe Consumption of APIs
Treat third-party API responses as untrusted input — validate before using them in queries or templates.
