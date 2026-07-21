# Common Web Attack Patterns

The generic catalog of named attacks — what each is, the *shape* of its code
signal (language-agnostic), and the prevention. Each is tagged with its OWASP
category; see [owasp-top10.md](owasp-top10.md) for the taxonomy. Concrete
per-framework code lives in the stack adapters (`stacks/rails.md`,
`stacks/react.md`).

Every attack below is one instance of the universal trust-boundary failure:
untrusted input reaches a sink without being made safe first.

---

## Injection Attacks

### SQL Injection — *A05*
Untrusted input concatenated into a query string instead of bound as a parameter.
- **Code signal:** a query assembled by string-building with user input, where a
  parameter placeholder should be used.
- **Prevention:** parameterized/prepared queries; never interpolate user input
  into query text.

### Command Injection — *A05*
Untrusted input placed into a string handed to an OS shell.
- **Code signal:** a shell command built from user input (interpolation into a
  command string, or a single string passed to a shell-invoking API).
- **Prevention:** avoid the shell; use an argument-array/exec API so input is a
  literal argument, never parsed as shell syntax.

### Template Injection (SSTI) — *A05*
Untrusted input rendered *as* a template, allowing code execution.
- **Code signal:** a template engine compiling a string that contains user input
  (rather than binding user input as template *data*).
- **Prevention:** never compile user-controlled template strings; use fixed,
  allowlisted templates and pass user data as escaped variables.

### ReDoS (Regular Expression DoS) — *A06*
Malicious input triggers catastrophic backtracking in a regex.
- **Code signal:** nested quantifiers (`(a+)+`, `(\w+)*`) or overlapping
  alternation applied to a user-controlled string.
- **Prevention:** simple/linear patterns, length-cap input before matching, or a
  backtracking-free regex engine.

---

## Cross-Site Attacks

### Stored XSS — *A05 (Injection)*
Malicious script saved to the datastore, executed when other users view it.
- **Code signal:** user-controlled content written to the page as HTML rather than
  text (an escape-bypassing render of stored data).
- **Prevention:** escape on output (the default in modern view layers); never mark
  user content as trusted HTML; enforce CSP.

### Reflected XSS — *A05 (Injection)*
Malicious script echoed straight from the request into the response.
- **Code signal:** a request parameter written into HTML output without escaping.
- **Prevention:** escape all user-controlled output; enforce CSP.

### DOM-Based XSS — *A05 (Injection)*
Client-side JavaScript writes user-controlled data into the DOM as markup.
- **Code signal:** a value from `location.*`/user input assigned to `innerHTML`,
  `document.write`, or `insertAdjacentHTML`.
- **Prevention:** write text (`textContent`), not markup; sanitize before any DOM
  HTML injection.

### CSRF (Cross-Site Request Forgery) — *A01*
An attacker's page triggers state-changing requests on an authenticated user's
session.
- **Code signal:** a state-changing, **cookie-authenticated** endpoint that
  doesn't verify an anti-CSRF token or the `Origin` header.
- **Prevention:** anti-CSRF tokens on mutations, `SameSite=Strict/Lax` cookies,
  verify `Origin` on APIs. (Token-authenticated APIs that don't use cookies are
  not exposed.)

### Clickjacking — *A02*
A transparent iframe overlays a legitimate page to steal clicks.
- **Code signal:** responses missing `X-Frame-Options` / CSP `frame-ancestors`.
- **Prevention:** `X-Frame-Options: SAMEORIGIN` or CSP `frame-ancestors`.

---

## Authentication & Session Attacks

### Session Fixation — *A07*
An attacker fixes a known session ID before login; the victim authenticates with
it.
- **Code signal:** the session identifier is not regenerated after authentication.
- **Prevention:** regenerate the session on privilege change (login), then set
  session data.

### Session Hijacking — *A07*
An attacker steals an active session cookie via XSS or network sniffing.
- **Code signal:** session cookies missing `HttpOnly` (XSS-readable), `Secure`
  (sent over HTTP), or `SameSite`.
- **Prevention:** `HttpOnly; Secure; SameSite` on all session cookies.

### Credential Stuffing / Brute Force — *A07*
Repeated automated login attempts using leaked or guessed credentials.
- **Code signal:** no rate limiting, lockout, or CAPTCHA on login/reset endpoints.
- **Prevention:** rate limiting, exponential backoff, account lockout, MFA.

### Insecure Password Reset — *A07*
Weak, guessable, or long-lived reset tokens.
- **Code signal:** predictable/sequential tokens, tokens that never expire, tokens
  delivered over HTTP or placed in a URL (logged in access logs/history).
- **Prevention:** cryptographically random, short-lived, single-use tokens over
  HTTPS.

---

## Access Control Attacks

### IDOR / BOLA (Insecure Direct Object Reference) — *A01 / API1*
Accessing another user's resource by guessing or incrementing an ID.
- **Code signal:** a lookup by user-supplied ID with no ownership/authorization
  scope applied.
- **Prevention:** scope every resource access to the requesting principal; check
  authorization on the specific object, not just the route.

### Path Traversal — *A01*
Accessing files outside the intended directory.
- **Code signal:** a filesystem path built from user input (file read/write/send
  keyed on a user-supplied name or path).
- **Prevention:** strip directory components, resolve and confirm the path stays
  within an allowed root, allowlist permitted names.

### Open Redirect — *A01*
Redirecting users to an attacker-controlled URL.
- **Code signal:** a redirect target taken from user input without validation.
- **Prevention:** allow only relative paths or an allowlist of hosts.

### Mass Assignment — *A08 / API3*
A user sets model attributes they shouldn't control (e.g. `admin`, `role_id`).
- **Code signal:** a request parameter bag bound to a model without an explicit
  allowlist of assignable fields.
- **Prevention:** explicit field allowlisting; never bind the whole parameter bag.

---

## Infrastructure Attacks

### SSRF (Server-Side Request Forgery) — *A02 / API7*
The **server** fetches a URL an attacker controls, reaching internal services or
cloud metadata (`169.254.169.254`).
- **Code signal:** a server-side HTTP request to a user-supplied URL without
  validation. (A *browser* `fetch` to a user URL is not SSRF — see
  [stacks/react.md](stacks/react.md).)
- **Prevention:** allowlist hosts/schemes, block private/link-local IP ranges,
  resolve-then-validate before fetching.

### XXE (XML External Entity) — *A05*
Malicious XML triggers external-entity resolution, reading local files or making
SSRF requests.
- **Code signal:** an XML parser processing untrusted input with external-entity
  resolution enabled.
- **Prevention:** disable external entities and network access in the parser.

### HTTP Header Injection — *A05*
User-controlled data injected into a response header (a newline splits headers).
- **Code signal:** a response header value set from unsanitized user input.
- **Prevention:** strip `\r`/`\n` from any user value placed in a header, or avoid
  it entirely.

### Directory Listing — *A02*
The web server exposes directory contents.
- **Code signal:** autoindex/directory browsing enabled, or a public dir with no
  index file.
- **Prevention:** disable directory listing in the web server config.

---

## Client-Side Security

### Tokens in Web Storage — *A02*
Auth tokens in `localStorage`/`sessionStorage` are readable by any XSS.
- **Code signal:** an auth token or session identifier written to web storage.
- **Prevention:** keep session tokens in `HttpOnly` cookies. (Full-stack decision:
  see [stacks/cross-stack.md](stacks/cross-stack.md).)

### Missing Content Security Policy — *A02*
No/weak CSP allows unrestricted script execution.
- **Code signal:** absence of a CSP, or `script-src *` / `'unsafe-inline'` without
  a nonce.
- **Prevention:** strict CSP — `default-src 'self'; script-src 'self' 'nonce-…'`.

### Prototype Pollution — *A08*
Modifying `Object.prototype` via unsanitized object merging.
- **Code signal:** a deep-merge of user-supplied JSON into an object without
  guarding `__proto__`/`constructor`.
- **Prevention:** null-prototype objects for untrusted dictionaries; validate
  structure before merging.
