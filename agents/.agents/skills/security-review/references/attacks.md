# Common Web Attack Patterns

Reference for the XSS/CSRF/Client agent and Infrastructure agent. Each attack: what it is, code signals to look for, prevention.

---

## Injection Attacks

### SQL Injection
User-controlled input passed into a database query as a string.
- **Code signals:** String interpolation in `.where()`, `.find_by_sql()`, raw `execute()`, `ActiveRecord::Base.connection.execute(string)`
- **Prevention:** Always use parameterized queries: `.where(name: name)` not `.where("name = '#{name}'")`

### Command Injection
User input passed to OS commands.
- **Code signals:** `` `#{user_input}` ``, `system("cmd #{input}")`, `exec(params[:cmd])`, `IO.popen(user_val)`
- **Prevention:** Avoid shell calls with user input entirely. If unavoidable, use array form: `system("ls", user_arg)`

### Template Injection (SSTI)
User input rendered as a template, allowing code execution.
- **Code signals:** `ERB.new(params[:template]).result`, `Liquid::Template.parse(user_input)` with unsafe filters
- **Prevention:** Never render user-controlled template strings. Use allowlisted templates.

### ReDoS (Regular Expression DoS)
Malicious input triggers catastrophic backtracking in regex.
- **Code signals:** Nested quantifiers like `(a+)+`, `(\w+)*`, complex alternation with overlap on user-controlled strings
- **Prevention:** Use simple regex patterns, impose input length limits before matching.

---

## Cross-Site Attacks

### Stored XSS
Malicious script saved to DB, executed when other users view it.
- **Code signals:** `raw user.bio`, `html_safe` on user content, `dangerouslySetInnerHTML={{ __html: user.content }}`, `innerHTML = userData`
- **Prevention:** Always escape output. Never use `html_safe` / `raw` on user-supplied content. Use CSP.

### Reflected XSS
Malicious script reflected in server response from request parameters.
- **Code signals:** `render inline: params[:message]`, echoing params directly into HTML without escaping
- **Prevention:** Escape all user-controlled output, use `h()` helper, enforce CSP.

### DOM-Based XSS
Client-side JavaScript writes user-controlled data into the DOM.
- **Code signals:** `document.write(location.href)`, `element.innerHTML = location.hash`, reading from `location.search` without sanitization
- **Prevention:** Use `textContent` not `innerHTML`. Sanitize before DOM manipulation.

### CSRF (Cross-Site Request Forgery)
Attacker's page triggers state-changing requests on an authenticated user's session.
- **Code signals:** Missing CSRF token verification, `protect_from_forgery` disabled, `skip_before_action :verify_authenticity_token` without justification, API endpoints accepting cookies without CSRF check
- **Prevention:** CSRF tokens for forms, `SameSite=Strict/Lax` cookies, verify `Origin` header on APIs.

### Clickjacking
Transparent iframe overlays legitimate page to steal clicks.
- **Code signals:** Missing `X-Frame-Options: DENY` or `Content-Security-Policy: frame-ancestors 'none'`
- **Prevention:** Set `X-Frame-Options: SAMEORIGIN` or CSP `frame-ancestors`.

---

## Authentication & Session Attacks

### Session Fixation
Attacker sets a known session ID before login; victim authenticates with it.
- **Code signals:** Session ID not regenerated after login (`reset_session` or `session.options[:renew]` missing post-authentication)
- **Prevention:** Always call `reset_session` before logging in, then set session data.

### Session Hijacking
Attacker steals active session cookie via XSS or network sniffing.
- **Code signals:** Cookies missing `HttpOnly` (XSS-readable), `Secure` (sent over HTTP), or `SameSite` (CSRF-exploitable)
- **Prevention:** `HttpOnly; Secure; SameSite=Lax` on all session cookies.

### Credential Stuffing / Brute Force
Repeated automated login attempts using leaked credentials.
- **Code signals:** No rate limiting on `/sessions`, `/passwords`, no account lockout, no CAPTCHA
- **Prevention:** `rack-attack` or equivalent rate limiting, exponential backoff, MFA.

### Insecure Password Reset
Weak, guessable, or long-lived reset tokens.
- **Code signals:** Sequential or MD5-based tokens, tokens that never expire, reset link sent over HTTP, token in URL (logged in server access logs)
- **Prevention:** `SecureRandom.urlsafe_base64(32)`, short expiry (15 min), single-use, HTTPS only.

---

## Access Control Attacks

### IDOR (Insecure Direct Object Reference)
Accessing another user's resource by guessing/incrementing an ID.
- **Code signals:** `Resource.find(params[:id])` without scoping to current user/account
- **Prevention:** Always scope: `current_user.resources.find(params[:id])`

### Path Traversal
Accessing files outside the intended directory.
- **Code signals:** `File.read(params[:filename])`, `send_file(params[:path])`, string concatenation for file paths with user input
- **Prevention:** `File.basename()` to strip directory components, allowlist permitted filenames.

### Open Redirect
Redirecting users to an attacker-controlled URL.
- **Code signals:** `redirect_to params[:return_to]` without validation, `redirect_to params[:url]`
- **Prevention:** Validate redirect URL is relative or matches allowlisted hosts.

### Mass Assignment
User sets model attributes they shouldn't control (e.g., `admin: true`, `role_id`).
- **Code signals:** `User.new(params[:user])` without strong params, `update(params)` without permit list
- **Prevention:** Strong parameters with explicit `.permit(:field1, :field2)`. Never `.permit!`

---

## Infrastructure Attacks

### SSRF (Server-Side Request Forgery)
Server fetches a URL attacker controls, reaching internal services.
- **Code signals:** `Net::HTTP.get(URI(params[:url]))`, `open(params[:url])`, `Faraday.get(user_url)`, `fetch(userProvidedUrl)`
- **Prevention:** Allowlist permitted hosts/domains, block private IP ranges (10.x, 172.16.x, 192.168.x, 169.254.x), parse and validate URL before fetching.

### XXE (XML External Entity)
Malicious XML triggers external entity resolution, reading local files or making SSRF requests.
- **Code signals:** `Nokogiri::XML(user_input)` without `NONET | NOENT` flags, `REXML::Document.new(user_xml)`
- **Prevention:** Disable external entity processing: `Nokogiri::XML(input) { |c| c.noent.nonet }`

### HTTP Header Injection
User-controlled data injected into HTTP response headers.
- **Code signals:** `response.headers['X-Custom'] = params[:val]` with no sanitization (newline in value splits headers)
- **Prevention:** Strip `\r\n` from any user value placed in headers, or avoid entirely.

### Directory Listing
Web server exposing directory contents.
- **Code signals:** Nginx/Apache config without `autoindex off`, missing `index.html` in public directories
- **Prevention:** `autoindex off` in web server config.

---

## Client-Side Security

### localStorage for Tokens
Storing auth tokens in `localStorage` makes them readable by any XSS.
- **Code signals:** `localStorage.setItem('token', jwt)`, `sessionStorage.setItem('auth', ...)`
- **Prevention:** Use `HttpOnly` cookies for session tokens instead.

### Missing Content Security Policy
No CSP header allows unrestricted script execution.
- **Code signals:** Absence of `Content-Security-Policy` header, `script-src *` or `unsafe-inline` without nonce
- **Prevention:** Strict CSP: `default-src 'self'; script-src 'self' 'nonce-{random}'`

### Prototype Pollution
Modifying `Object.prototype` via unsanitized object merging.
- **Code signals:** Deep merge of user-supplied JSON into objects, `_.merge(target, user_obj)` without sanitization
- **Prevention:** Use `Object.create(null)` for dictionaries, validate JSON structure before merging.
