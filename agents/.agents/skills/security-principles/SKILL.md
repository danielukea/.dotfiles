---
name: security-principles
description: >
  Durable, framework-agnostic security principles for judging whether code is
  safe: trust-boundary analysis, the OWASP Top 10 (2025) and API Security Top 10
  (2023) categories, named attack patterns (injection, XSS, CSRF, IDOR, SSRF, and
  more), and what your framework already guarantees automatically (Rails and
  React stack adapters included). Use when writing
  or evaluating security-sensitive code (auth, sessions, payments, file uploads,
  admin functions, cryptography), or when a user says "security review", "security
  audit", "check for vulnerabilities", "OWASP compliance", "find security issues",
  "secure this code", "is this safe?", or "could this be exploited?". Teaches WHAT
  makes code safe and WHAT the framework already guarantees — apply these lenses
  directly wherever they bear on the code in front of you.
allowed-tools: Read, Grep, Glob, Bash
---

# Security Principles

Every security judgment reduces to two questions: how far does untrusted data
travel before it's made safe, and where is authorization assumed instead of
checked? The categories below are lenses on those questions — use whichever bear
on the code in front of you.

## Trust boundaries — the one universal lens

The first question, and the one nearly every injection/XSS/SSRF category is a
special case of: does attacker-controlled data (params, headers, uploaded files,
webhook/API payloads, even another user's stored data) reach a sink — a query, shell command, template render, DOM write,
filesystem path, deserializer, or outbound HTTP call — without being validated,
escaped, parameterized, or scoped to the requester first? Code is only vulnerable
if you can name both the untrusted source and the unguarded sink. A scary-looking
sink fed only by constants or server-generated values is safe.

### Confirming the source is actually untrusted

A dangerous-looking sink is only a vulnerability when untrusted data reaches it.
Before treating one as real, confirm:

1. **Is the value actually user-controlled?** Or is it a constant, a config value,
   or a server-generated value? (`"admin"` marked HTML-safe is safe; `params[:x]`
   marked HTML-safe is not.)
2. **Does the framework handle this by default?** Modern view layers escape output,
   ORMs parameterize queries — the stack adapter says which.
3. **Is a library or initializer already mitigating it?** Auth, authorization,
   rate-limiting, and header libraries cover whole classes of sink.
4. **Is the code a test fixture or factory?** Security rules are relaxed there.

The guarantee is only real when you can name the mechanism — not a vague "the
framework handles it."

## OWASP as a coverage map, not ten things to memorize

Group the Top 10 by the question each theme is really asking:

| Theme                       | Categories                             | The question                                                                                    |
| --------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------------- |
| Access & authorization      | A01, API1 (BOLA/IDOR), API5            | Is every resource access scoped to its owner, not just gated at the route?                      |
| Injection & untrusted input | A05, A08                               | Does untrusted data reach a query/shell/template/deserializer unparameterized?                  |
| Auth & session              | A07, API2                              | Is the session invalidated/regenerated at the right moments, are tokens random and short-lived? |
| Crypto & secrets            | A04                                    | Passwords hashed with a slow KDF (bcrypt/Argon2, not MD5/SHA1); tokens from a CSPRNG (not a fast PRNG)? |
| Client-side & cross-site    | XSS, CSRF, clickjacking, open redirect | Is output escaped, and are state-changing requests verified?                                    |
| Infrastructure & config     | A02, A03, API7 (SSRF), API8            | Headers, CORS, dependency freshness, outbound URL fetches validated?                            |
| Design & observability      | A06, A09, A10                          | Rate limits and lockouts present; security events logged; errors fail closed?                   |

The category taxonomy — what each asks, plus the API Security Top 10 — is the
compliance index [owasp-top10.md](references/owasp-top10.md). The named-attack
catalog with generic code signals (SQLi, SSTI, ReDoS, session fixation, IDOR,
SSRF, XXE, prototype pollution, and more) is [attacks.md](references/attacks.md).

## Know your framework's guarantees

Half of would-be vulnerabilities are already handled by the framework — know which
so you neither reinvent them nor mistake safe code for unsafe. Nearly every modern
web framework, by default:

- **escapes template/JSX output** — an interpolated value is safe unless the code
  explicitly opts out (a `raw`/`html_safe`/`dangerouslySetInnerHTML` equivalent);
- **parameterizes ORM queries** — injectable only when the code builds raw query
  strings;
- **protects state-changing requests** — anti-CSRF tokens on cookie-authenticated
  mutations, on by default.

Which protections apply, their exact opt-out forms, and the library guarantees
(auth, authorization, rate limiting, security headers) live in the stack adapter —
see below.

## Severity

Severity is exploitability times preconditions — how directly an attacker can
reach the sink, and what they need in place first:

- **Critical** — directly exploitable, no auth required, or an auth bypass
  (RCE, SQLi on a public endpoint).
- **High** — exploitable with authentication or by chaining (IDOR, stored XSS,
  session fixation, SSRF to an internal service).
- **Medium** — requires specific conditions (reflected XSS, missing rate limit
  on a sensitive endpoint, weak token generation).
- **Low** — defense-in-depth gaps (missing CSP/security headers, verbose error
  messages).

## Stack adapters

Everything above is framework-agnostic. Each stack adapter holds that stack's
vulnerable/safe code pairs *and* its "what's already handled" guarantees. Detect
the stack from the project root and load the matching adapter:

| Marker | Adapter |
| --- | --- |
| `Gemfile` | [stacks/rails.md](references/stacks/rails.md) — strong params, ActiveRecord injection, CSRF, sessions, Devise/Pundit/Rack::Attack, timing attacks |
| `package.json` with React (`*.tsx`/`*.jsx`) | [stacks/react.md](references/stacks/react.md) — dangerouslySetInnerHTML, token storage, postMessage, CSP, dependency risk |
| both (full-stack) | also load [stacks/cross-stack.md](references/stacks/cross-stack.md) — CSRF token handoff, token-storage decision, CSP coordination |
| other stack | add a `stacks/<tech>.md` adapter following the same shape |

The generic catalog applies regardless of stack; the adapter adds the specifics.
