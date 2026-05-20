---
name: security-review
description: >
  Complete security review of a diff or codebase against OWASP Top 10 2025,
  OWASP API Security Top 10 2023, and common web attack patterns. Dispatches
  7 parallel agents across injection, authentication, access control, cryptography,
  XSS/CSRF, infrastructure, and dependency risks — followed by a false positive
  reviewer that filters out cases the framework already handles (Rails auto-escaping,
  ActiveRecord parameterization, Devise session management, etc.). Returns
  severity-tagged findings (critical/high/medium/low) with OWASP category,
  file:line evidence, and concrete remediation steps. Always invoke when the user says "security review", "security
  audit", "check for vulnerabilities", "OWASP compliance", "find security issues",
  "secure this code", "/security-review", or before merging any PR that touches
  authentication, sessions, user input handling, file uploads, payments, admin
  functions, cryptography, or external API integrations. Also invoke when the
  user asks "is this safe?", "could this be exploited?", or "review this for
  security" — even if the request seems narrow, the parallel agent approach
  catches cross-cutting issues a targeted review would miss.
user-invokeable: true
allowed-tools: Read, Grep, Glob, Bash, Agent, AskUserQuestion, Skill
---

# Security Review

You are running a comprehensive OWASP-grounded security review using 7 parallel specialist agents followed by a false positive reviewer.

## Phase 1: Determine Scope

**What to analyze:**

1. If on a feature branch with changes → use the diff:
   ```bash
   git diff main...HEAD --stat
   git diff main...HEAD
   ```
2. If the user specified a file or path → read those files directly
3. If no diff and no path → scan the most security-sensitive areas of the codebase:
   - Auth controllers/services
   - Any file matching `*auth*`, `*session*`, `*password*`, `*token*`, `*permission*`, `*role*`, `*admin*`
   - API controllers
   - Models handling user data or payments

**Detect the stack:**
- `Gemfile` present → Rails
- `*.tsx`, `*.jsx`, `package.json` → React/TypeScript
- Both → full-stack
- Load the relevant stack reference file before dispatching agents

**Gather context for agents:**
- Run `git diff main...HEAD` (or read files) and capture the code to review
- Note the tech stack
- Note any obviously sensitive areas (auth, payments, admin)

## Phase 2: Dispatch 7 Parallel Security Agents

Dispatch ALL of these in a single message so they run in parallel. Each agent should read the relevant reference files and produce findings in the standard format.

Give every agent:
- The code/diff to review (paste it in the prompt — don't ask them to re-fetch)
- The stack context
- Their specific lens (what to look for)
- The output format below
- Path to `references/owasp-top10.md` and `references/attacks.md` in this skill's directory
- Path to the stack-specific file if applicable

### Agent 1: Injection

**Lens:** SQL injection, command injection, template injection, LDAP/XPath injection, ReDoS, code injection via `eval`.

**Read:** `references/owasp-top10.md` (A05 section), `references/attacks.md` (Injection Attacks section), `references/stacks/rails.md` if Rails.

Look for string interpolation in database queries, any use of `system()`/backticks/`exec()` with user input, `eval()`, `render inline:`, `YAML.load` (not `.safe_load`), `Marshal.load`.

### Agent 2: Authentication & Session

**Lens:** Login flows, session management, password reset, brute force protection, MFA gaps, token security.

**Read:** `references/owasp-top10.md` (A07 section), `references/stacks/rails.md` (Session Security, Devise-Specific, Rate Limiting sections) if Rails.

Look for: missing `reset_session` on login/logout, weak token generation, no rate limiting on auth endpoints, tokens in URLs or logs, password reset tokens that don't expire, missing `HttpOnly`/`Secure`/`SameSite` on session cookies.

### Agent 3: Access Control

**Lens:** Broken access control, IDOR, privilege escalation, missing authorization, mass assignment.

**Read:** `references/owasp-top10.md` (A01, API1, API5 sections), `references/stacks/rails.md` (Authorization, Strong Parameters sections) if Rails.

Look for: `Model.find(params[:id])` without scoping to current user, missing `authorize!`/`policy()` calls, admin endpoints without role checks, `.permit!`, parameters passed to `create`/`update` without allowlisting.

### Agent 4: Data Protection & Cryptography

**Lens:** Secrets in code, weak hashing, improper encryption, sensitive data exposure, insecure randomness.

**Read:** `references/owasp-top10.md` (A04 section), `references/stacks/rails.md` (Secrets & Configuration, Timing Attacks sections) if Rails.

Look for: API keys/passwords hardcoded or in committed config files, MD5/SHA1 for password hashing, `rand()` for security tokens (use `SecureRandom`), JWT with weak secret, `==` for token comparison (use constant-time compare), sensitive data logged.

### Agent 5: XSS / CSRF / Client-Side

**Lens:** All XSS variants (stored, reflected, DOM), CSRF, clickjacking, open redirect, prototype pollution, localStorage tokens.

**Read:** `references/attacks.md` (Cross-Site Attacks, Client-Side Security sections), `references/stacks/rails.md` (XSS/HTML Injection, CSRF, Open Redirect sections) if Rails, `references/stacks/react.md` if React.

Look for: `.html_safe`/`raw()` on user content, `dangerouslySetInnerHTML` with user data, `innerHTML =` with user data, missing CSRF token verification, `redirect_to params[:return_to]` without validation, missing `X-Frame-Options` or `frame-ancestors` CSP, `localStorage` storing auth tokens.

### Agent 6: Infrastructure & Configuration

**Lens:** SSRF, security misconfiguration, missing headers, CORS, path traversal, XXE, file upload risks, information disclosure.

**Read:** `references/owasp-top10.md` (A02, API7, API8 sections), `references/attacks.md` (Infrastructure Attacks section).

Look for: `Net::HTTP.get(user_url)` / `fetch(userUrl)` without URL validation, permissive CORS headers, missing security headers (CSP, HSTS, X-Content-Type-Options), `File.read(params[:path])` / `send_file(params[:path])` without validation, `Nokogiri::XML(user_input)` without noent/nonet flags, verbose error responses including stack traces, debug endpoints in production.

### Agent 7: Dependencies & Supply Chain

**Lens:** Vulnerable packages, outdated dependencies, supply chain risks.

**Read:** `references/owasp-top10.md` (A03 section).

Actions:
- If Rails: run `bundle audit check --update` if available, or check `Gemfile.lock` for known vulnerable gems
- If Node: check `package.json` / `package-lock.json` for outdated packages; flag any with known CVEs
- Flag any `eval()` of remotely-fetched code, `require()` of URLs, or dynamic imports from user-controlled sources
- Note any packages that haven't been updated in 2+ years that handle security-sensitive operations (auth, crypto, parsing)

---

### Agent Output Format

Each agent must return findings in this exact format. Max 5 findings. Skip categories with no issues — don't pad with "no issues found" for every non-issue.

```
## [Agent Name] Findings

### Finding: [one-line description]
- **OWASP:** [category, e.g. "A05 Injection" or "API1 BOLA"]
- **Severity:** critical | high | medium | low
- **Evidence:** `file/path.rb:42` — [quote the relevant code snippet]
- **Impact:** [what an attacker can do if this is exploited]
- **Fix:** [concrete code change or configuration, not vague advice]

### Finding: ...
```

If no findings in your lens: return `## [Agent Name] Findings\n\nNo issues found.`

---

## Phase 2.5: False Positive Review (sequential — run AFTER all 7 agents complete)

Once you have all 7 agents' raw findings, spawn one more agent to review them for false positives before synthesizing. This agent is a skeptic — its job is to catch cases where the pattern looks dangerous but the framework, library, or surrounding code already handles it.

**Give this agent:**
- The complete raw findings from all 7 agents (paste them in full)
- The original code/diff being reviewed
- The detected stack
- Path to `references/framework-mitigations.md`

**Agent 8: False Positive Reviewer**

**Lens:** For each finding from agents 1–7, determine whether it is:
- **Confirmed** — genuine vulnerability, finding stands
- **Downgrade** — real concern but lower severity than flagged (e.g., Rails mass assignment crashes rather than silently assigns — medium not critical)
- **Dismissed** — framework/library mitigates this, or the flagged value is not actually user-controlled

**Read:** `references/framework-mitigations.md` carefully before evaluating. Key things to check:
- Is the value actually user-controlled, or is it a constant, translation string, or server-generated value?
- Does Rails auto-escape this output (ERB `<%= %>` without `html_safe`/`raw`)?
- Does ActiveRecord parameterize this query (hash/array form vs. string interpolation)?
- Is Devise handling session regeneration, bcrypt hashing, or token expiry for this?
- Is Pundit/CanCanCan's `load_and_authorize_resource` or `after_action :verify_authorized` active in scope?
- Is Rack::Attack or SecureHeaders already covering this?
- Is this code in a test/spec file (different rules apply)?
- For React: is this JSX text interpolation (auto-escaped) vs. `dangerouslySetInnerHTML`?
- For "SSRF": is this client-side `fetch()` in the browser (not SSRF) vs. server-side HTTP request?

**Output format:**

```
## False Positive Review

### Confirmed (no change)
- **[original finding title]** — [one sentence why it's genuine]

### Downgraded
- **[original finding title]** — Severity: [old] → [new]. Reason: [specific mechanism, e.g. "Rails 4+ raises ForbiddenAttributesError on unpermitted params — will crash rather than silently assign admin: true"]

### Dismissed
- **[original finding title]** — False positive: [specific reason, e.g. "Rails ERB auto-escapes `<%= user.name %>` — no html_safe/raw call present, so XSS is not possible here"]
- **[original finding title]** — False positive: [specific reason, e.g. "Devise calls reset_session internally during sign_in — no manual call needed"]
```

If all findings are confirmed, return `## False Positive Review\n\nAll findings confirmed.`

---

## Phase 3: Synthesize Results

After all 8 agents complete (7 parallel + false positive reviewer):

1. **Apply FP review:** Remove dismissed findings entirely. Adjust severity for downgraded findings. Note any dismissals briefly in the "What Looks Good" section to show the reviewer that the concern was considered.

2. **Convergence:** If ≥2 agents flagged the same file/function (after FP removal), promote severity by one level (medium → high, high → critical). Note the convergence.

3. **Deduplicate:** Merge near-identical findings from different agents into one, citing both OWASP categories.

4. **Present the report:**

```markdown
## Security Review: [branch name / file / scope]

**Stack:** [Rails / React / Full-stack]
**Scope:** [diff (N files, +X/-Y lines) / targeted scan / full codebase]
**Agents run:** Injection · Auth · Access Control · Crypto · XSS/CSRF · Infra · Dependencies · FP Review

---

### 🚨 Critical
[findings]

### ⚠️ High
[findings]

### 📋 Medium
[findings]

### 💡 Low
[findings]

---

### ✅ What Looks Good
[Patterns done well — only mention things genuinely present, not generic praise. Include a brief note on any dismissed false positives so the developer knows those patterns were reviewed: e.g., "Rails auto-escaping covers all ERB output — XSS via template rendering not a concern here."]

---

### 🔍 Dismissed (Framework Handles)
[Only include this section if findings were dismissed. One line per dismissal explaining what was reviewed and why it's safe. Omit section entirely if nothing was dismissed.]

---

### OWASP Coverage Map
| Category | Findings |
|----------|----------|
| A01 Broken Access Control | ✅ Clean / ⚠️ N finding(s) |
| A02 Security Misconfiguration | ... |
| A03 Supply Chain | ... |
| A04 Cryptographic Failures | ... |
| A05 Injection | ... |
| A06 Insecure Design | ... |
| A07 Auth Failures | ... |
| A08 Integrity Failures | ... |
| A09 Logging Failures | ... |
| A10 Exception Handling | ... |
| API Top 10 | [note if any API-specific issues found] |
```

**Format for each finding in the report:**

```
- **`path/to/file.rb:42`** — [A05] SQL injection via string interpolation in search query.  
  Attacker can dump the users table. **Fix:** Use `.where(name: params[:name])` instead of `"WHERE name = '#{params[:name]}'"`.
```

---

## Notes on Severity

- **Critical:** Directly exploitable, no authentication required, or auth bypass. Remote code execution, SQL injection on public endpoint, auth bypass.
- **High:** Exploitable with authentication or requires chaining. IDOR, stored XSS, session fixation, SSRF to internal services.
- **Medium:** Requires specific conditions. Reflected XSS, missing rate limiting on sensitive endpoint, weak token generation.
- **Low:** Defense-in-depth gaps, missing headers, informational disclosure that aids an attacker. Missing CSP, verbose error messages.

When in doubt, lean toward reporting rather than suppressing — the developer can decide to accept the risk.
