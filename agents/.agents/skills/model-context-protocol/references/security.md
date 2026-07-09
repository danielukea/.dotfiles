# MCP Authorization and Security

## Authorization framework

OAuth 2.1-based, **transport-level**, and **OPTIONAL**. Applies to HTTP transports (SHOULD
conform). **stdio SHOULD NOT use this framework** — it retrieves credentials from the environment
instead. Other custom transports MUST follow their own protocol's best practices.

**Roles:** MCP server = OAuth 2.1 **resource server**; MCP client = OAuth 2.1 **client**; a
separate **authorization server** (may be co-hosted or external) issues tokens.
**Standards subset:** OAuth 2.1 draft-13, RFC 8414 (AS metadata), RFC 7591 (Dynamic Client
Registration), RFC 9728 (Protected Resource Metadata), and the OAuth Client ID Metadata Document draft.

### Discovery

- MCP servers MUST implement **RFC 9728 Protected Resource Metadata**, including `authorization_servers` (≥1). Clients MUST use it for AS discovery.
- Server advertises resource metadata via a `WWW-Authenticate` header on **401** with
  `resource_metadata="..."`, and/or a well-known URI (`/.well-known/oauth-protected-resource[/path]`).
  Clients MUST support both, preferring the header when present.

  ```http
  HTTP/1.1 401 Unauthorized
  WWW-Authenticate: Bearer resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource",
                           scope="files:read"
  ```

- AS metadata discovery MUST try both RFC 8414 and OpenID Connect Discovery 1.0 well-known
  endpoints, in a defined priority order.

### Client registration (priority order)

1. **Pre-registration** (static client credentials), if available.
2. **Client ID Metadata Documents (CIMD)** — _recommended, new in `2025-11-25`_. The client's
   `client_id` is an **HTTPS URL** pointing to a JSON doc (`client_id` must equal the URL,
   `client_name`/`redirect_uris` required). AS advertises support via
   `client_id_metadata_document_supported: true`. Solves "no prior relationship."
3. **Dynamic Client Registration (RFC 7591)** — now positioned only for backwards compatibility.
4. Prompt the user, as a last resort.

### PKCE (required)

Clients MUST implement PKCE and MUST verify PKCE support via AS metadata **before proceeding** —
if `code_challenge_methods_supported` is absent, the client MUST refuse. MUST use `S256` when capable.

### Resource indicators (RFC 8707) — mandatory

Client MUST include the `resource` parameter in **both** authorization and token requests,
identifying the MCP server by its canonical URI (lowercase scheme/host, no fragment), e.g.
`&resource=https%3A%2F%2Fmcp.example.com`. Send it even if the AS doesn't advertise support. This
binds tokens to their intended audience.

### Token usage & validation

- Client MUST send `Authorization: Bearer <token>` on every HTTP request; tokens MUST NOT appear in the URI query string.
- Server MUST validate the token was issued **specifically for it** (audience check). Invalid/expired → **401**.
- Server MUST NOT accept or transmit tokens issued for anyone else; if it calls an upstream API it
  MUST use a **separate** token — never pass through the client's token.

| Code | Meaning      | Use                                       |
| ---- | ------------ | ----------------------------------------- |
| 401  | Unauthorized | Auth required or token invalid            |
| 403  | Forbidden    | Invalid scopes / insufficient permissions |
| 400  | Bad Request  | Malformed authorization request           |

### Step-up / incremental scope consent (new in `2025-11-25`)

On insufficient scope at runtime, server SHOULD return **403** with
`WWW-Authenticate: Bearer error="insufficient_scope", scope="...", resource_metadata="..."`. Client
SHOULD re-authorize for the larger scope and retry a limited number of times. Use least privilege —
request incrementally, from the challenge's `scope` if present.

### Other authz requirements

All AS endpoints MUST be HTTPS; redirect URIs MUST be `localhost` or HTTPS, pre-registered, and
validated by **exact string match**. Clients SHOULD use/verify `state`. AS SHOULD issue short-lived
access tokens and MUST rotate refresh tokens for public clients.

## Named attack patterns

All from the spec's security best-practices page, **except** Elicitation URL phishing, which is
documented on the client/elicitation page instead (noted in its row below).

| Attack                                                                                                          | How it works                                                                                                                                                                                                                 | Mitigation                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| --------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Confused deputy**                                                                                             | A proxy server with a _static_ client ID to a third-party AS + dynamic client registration + a leftover third-party consent cookie → attacker skips the consent screen and steals an auth code via a crafted `redirect_uri`. | Proxy MUST get **per-client consent before** forwarding to the third-party AS; maintain a per-user registry of approved `client_id`s; consent page MUST show client name, scopes, and exact `redirect_uri`; CSRF-protect it; block iframing. `state` MUST be crypto-random, single-use, short-lived, set only _after_ consent. Consent cookies MUST use `__Host-` prefix, `Secure`/`HttpOnly`/`SameSite=Lax`, be signed/server-side, and bound to the specific `client_id`. |
| **Token passthrough**                                                                                           | Server accepts a token not issued for it and forwards it downstream.                                                                                                                                                         | **Explicitly forbidden.** Server MUST NOT accept any token not explicitly issued for it — breaks rate-limiting, audit trails, and trust boundaries, and enables exfiltration.                                                                                                                                                                                                                                                                                               |
| **SSRF via OAuth discovery**                                                                                    | Malicious server points `resource_metadata`/`authorization_servers`/AS metadata endpoints at internal URLs (cloud metadata IP, private ranges, `localhost`).                                                                 | Clients MUST consider SSRF risk; the specific tactics are SHOULD-level: enforce HTTPS (loopback exception), block private/reserved IP ranges (`10/8`, `172.16/12`, `192.168/16`, `127/8`, `169.254/16`, `fc00::/7`, `fe80::/10`) without hand-rolling IP parsing, validate redirect targets, watch DNS-rebinding/TOCTOU.                                                                                                                                                    |
| **Session hijacking**                                                                                           | Two variants: prompt injection via a shared event queue across stateful servers, and impersonation by reusing a session ID.                                                                                                  | Servers MUST verify all inbound requests and MUST NOT use sessions for authentication. Session IDs MUST be secure/non-deterministic (CSPRNG UUIDs); SHOULD bind to user identity (e.g. `<user_id>:<session_id>`) so guessing an ID can't impersonate a user; rotate/expire IDs.                                                                                                                                                                                             |
| **Local MCP server compromise**                                                                                 | Malicious startup command in client config (e.g. exfiltrating `~/.ssh/id_rsa`), a malicious payload inside the server itself, or DNS rebinding to a local HTTP server.                                                       | One-click config MUST show the exact untruncated command and require explicit consent; SHOULD sandbox spawned servers and warn on `sudo`/`rm -rf`/sensitive-path access; local servers SHOULD use stdio or restrict HTTP (auth token, Unix domain sockets).                                                                                                                                                                                                                 |
| **OAuth authorization-URL injection**                                                                           | Malicious server returns a `javascript:`/`data:`/`file:` URL → XSS/RCE when the client opens it.                                                                                                                             | Client MUST allow only `http` (loopback)/`https` schemes (allowlist, reject dangerous ones), MUST NOT open URLs via a shell, use CSP, sanitize.                                                                                                                                                                                                                                                                                                                             |
| **stdio-in-proxy privilege escalation**                                                                         | Stolen proxy auth token (via XSS) lets an attacker make the proxy spawn arbitrary stdio commands → RCE.                                                                                                                      | Fix the upstream XSS/URL-scheme issue; sandbox spawned processes.                                                                                                                                                                                                                                                                                                                                                                                                           |
| **Elicitation URL phishing** _(sourced from the client/elicitation page, not the security-best-practices page)_ | Alice starts a URL-mode elicitation, tricks Bob into completing it → tokens bind to Alice, giving account takeover.                                                                                                          | Server MUST ensure the user who started the elicitation is the same user who completes it (e.g. match session-cookie `sub`). Clients MUST NOT pre-fetch/auto-open URL-mode URLs without explicit consent, MUST show the full URL, SHOULD highlight domain and warn on Punycode.                                                                                                                                                                                             |
| **Scope over-grant**                                                                                            | Publishing omnibus scopes (`*`, `full-access`) instead of granular ones.                                                                                                                                                     | Use progressive least-privilege scopes with step-up challenges (see incremental consent above).                                                                                                                                                                                                                                                                                                                                                                             |

## Foundational principles

The base spec's non-negotiables, restated because MCP "cannot enforce these at the protocol
level" — implementers must build the actual consent/authorization flows:

- **User consent & control** for data access, tool invocation, and LLM sampling.
- **Data privacy** — hosts MUST get consent before exposing user data, and MUST NOT retransmit
  resource data without consent.
- **Tool safety** — tools can mean arbitrary code execution; require consent before invocation, and
  ensure users understand what each tool does before it runs (a reasonable practice, though the
  spec doesn't phrase it as a formal "SHOULD show tool inputs" requirement — treat this as guidance,
  not a quoted MUST/SHOULD).
- **Rate limiting** has no dedicated spec page of its own — it only shows up as scattered SHOULDs
  (the completion utility recommending servers debounce/rate-limit, and the general "protect
  against abuse" framing in the sections above) — so don't go looking for a standalone rate-limit
  section elsewhere in the spec; this is the complete picture of what's documented.

## Sources (exact URLs fetched, July 2026, `2025-11-25` spec)

- https://modelcontextprotocol.io/specification/2025-11-25/basic/authorization
- https://modelcontextprotocol.io/specification/2025-11-25/basic/security_best_practices
- https://modelcontextprotocol.io/specification/2025-11-25/client/elicitation (source for the Elicitation URL phishing row above)

If re-verifying: these two pages are the canonical source for anything auth/security-shaped in
MCP — re-fetch under the then-current `/specification/<date>/basic/` path before trusting this
file against a newer revision.
