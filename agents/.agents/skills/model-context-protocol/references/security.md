# MCP Authorization and Security

**Structural note for `2026-07-28`:** the spec-level `basic/security_best_practices` page is **gone**
(it 307-redirects). Security content now lives in two places: normative auth requirements under
`/specification/2026-07-28/basic/authorization/*`, and the attack catalog as a **docs** page at
`/docs/2026-07-28/tutorials/security/security_best_practices`. Cite them accordingly — the docs page
is guidance-shaped even where it uses MUST language.

## Authorization framework

OAuth 2.1-based, **transport-level**, and **OPTIONAL**. Applies to HTTP transports (SHOULD conform).
**stdio SHOULD NOT use this framework** — it retrieves credentials from the environment instead. Other
custom transports MUST follow their own protocol's best practices.

**Roles:** MCP server = OAuth 2.1 **resource server**; MCP client = OAuth 2.1 **client**; a separate
**authorization server** (co-hosted or external) issues tokens.
**Standards subset:** OAuth 2.1 draft-13, RFC 8414 (AS metadata), RFC 7591 (DCR — now deprecated),
RFC 9728 (Protected Resource Metadata), **RFC 9207 (AS Issuer Identification)**, and the OAuth Client
ID Metadata Document draft.

### Discovery

- MCP servers MUST implement **RFC 9728 Protected Resource Metadata**, including
  `authorization_servers` (≥1). Clients MUST use it for AS discovery.
- Server advertises resource metadata via a `WWW-Authenticate` header on **401** with
  `resource_metadata="…"`, and/or a well-known URI
  (`/.well-known/oauth-protected-resource[/path]`). Clients MUST support both, preferring the header.

  ```http
  HTTP/1.1 401 Unauthorized
  WWW-Authenticate: Bearer resource_metadata="https://mcp.example.com/.well-known/oauth-protected-resource",
                           scope="files:read"
  ```

- AS metadata discovery MUST try both RFC 8414 and OpenID Connect Discovery 1.0 well-known endpoints,
  in a defined priority order.

### Client registration (priority order)

1. **Pre-registered** client information, if the client has it.
2. **Client ID Metadata Documents (CIMD)** — when the AS advertises
   `client_id_metadata_document_supported`. The `client_id` is an **HTTPS URL** pointing to a JSON doc
   (`client_id` must equal the URL; `client_name`/`redirect_uris` required). Solves "no prior
   relationship," which is the common MCP case.
3. **Dynamic Client Registration (RFC 7591)** — **Deprecated as of `2026-07-28`** (PR #2858) in favor
   of CIMD. Retained only for interop with authorization servers that don't support CIMD; eligible for
   removal in a revision released on or after 2027-07-28.
4. Prompt the user, as a last resort.

**Two new client obligations in `2026-07-28`:**
- **`application_type` is required on DCR** (SEP-837), because OIDC constrains redirect URIs by it.
  Native/desktop clients using custom schemes or loopback SHOULD use `"native"`; browser-based clients
  SHOULD use `"web"`. Getting this wrong causes redirect-URI conflicts.
- **Credentials are bound to their issuer** (SEP-2352). Clients using pre-registered credentials, or
  persisting DCR-obtained ones, **MUST** key them by the AS's `issuer` identifier. When the AS changes
  (detected via updated protected resource metadata), clients **MUST NOT** reuse credentials from a
  different AS and **MUST** re-register. On mismatch, clients **SHOULD** surface an error rather than
  silently trying them.

### PKCE (required)

Clients MUST implement PKCE and MUST verify PKCE support via AS metadata **before proceeding** — if
`code_challenge_methods_supported` is absent, the client MUST refuse. MUST use `S256` when capable.

### `iss` validation (RFC 9207) — new in `2026-07-28`

Authorization servers **SHOULD** include `iss` in authorization responses (including error responses),
and MUST advertise it via `authorization_response_iss_parameter_supported`. Clients **MUST** validate
before sending the code to any token endpoint:

| `authorization_response_iss_parameter_supported` | `iss` present? | Client action |
| --- | --- | --- |
| `true` | yes | Compare to recorded issuer (simple string comparison, RFC 3986 §6.2.1) |
| `true` | no | **Reject the response** |
| `false` / absent | yes | Compare anyway — accommodates ASes emitting `iss` before updating metadata |
| `false` / absent | no | Proceed |

**Comparison is byte-exact.** After form-decoding, clients **MUST NOT** apply scheme/host case folding,
default-port elision, trailing-slash, or percent-encoding normalization before comparing. A future
revision is expected to upgrade AS inclusion of `iss` from SHOULD to MUST — implement it now.

### Resource indicators (RFC 8707) — mandatory

Client MUST include the `resource` parameter in **both** authorization and token requests, identifying
the MCP server by its canonical URI (lowercase scheme/host, no fragment), e.g.
`&resource=https%3A%2F%2Fmcp.example.com`. Send it even if the AS doesn't advertise support. This binds
tokens to their intended audience.

### Token usage & validation

- Client MUST send `Authorization: Bearer <token>` on every HTTP request; tokens MUST NOT appear in the
  URI query string.
- Server MUST validate the token was issued **specifically for it** (audience check). Invalid/expired
  → **401**.
- Server MUST NOT accept or transmit tokens issued for anyone else; if it calls an upstream API it MUST
  use a **separate** token — never pass through the client's.

| Code | Meaning | Use |
| --- | --- | --- |
| 401 | Unauthorized | Auth required or token invalid |
| 403 | Forbidden | Invalid scopes / insufficient permissions |
| 400 | Bad Request | Malformed authorization request |

### Step-up / incremental scope consent

On insufficient scope at runtime, server SHOULD return **403** with
`WWW-Authenticate: Bearer error="insufficient_scope", scope="…", resource_metadata="…"`. Client SHOULD
re-authorize for the larger scope and retry a limited number of times. Request incrementally, from the
challenge's `scope` when present.

### Other authz requirements

All AS endpoints MUST be HTTPS; redirect URIs MUST be `localhost` or HTTPS, pre-registered, and
validated by **exact string match**. Clients SHOULD use/verify `state`. AS SHOULD issue short-lived
access tokens and MUST rotate refresh tokens for public clients.

## Named attack patterns

| Attack | How it works | Mitigation |
| --- | --- | --- |
| **State handle hijacking** *(new in `2026-07-28` — the successor to session hijacking)* | With no protocol sessions, servers mint explicit handles (cart id, workflow id) returned in tool results and passed back as ordinary tool arguments. An attacker obtains or guesses one and calls tools with it; a server that doesn't check ownership operates on the victim's state. | Servers implementing authorization **MUST** verify all inbound requests and **MUST NOT** treat possession of a handle as authentication. **SHOULD** use CSPRNG-generated, non-deterministic handles (never sequential), expire them, and **bind them server-side to the authenticated user** — key stored state as `<user_id>:<handle>` where the user id comes from the *verified token*, not the client — rejecting a handle presented by any other principal. |
| **`requestState` tampering** *(MRTR)* | `requestState` round-trips through the client, so a malicious client can alter it to change server behavior or bypass authorization. | Integrity-protect it (HMAC/AEAD) and reject what fails verification; bind principal + TTL + originating-request digest inside the protected payload. Full rules: [mrtr.md](mrtr.md#requeststate-is-attacker-controlled--treat-it-as-such). |
| **Confused deputy** | A proxy server with a *static* client ID to a third-party AS + dynamic client registration + a leftover consent cookie → attacker skips the consent screen and steals an auth code via a crafted `redirect_uri`. | Proxy MUST get **per-client consent before** forwarding to the third-party AS; keep a per-user registry of approved `client_id`s; consent page MUST show client name, scopes, and exact `redirect_uri`, be CSRF-protected, and block iframing. `state` MUST be crypto-random, single-use, short-lived, set only *after* consent. Consent cookies MUST use `__Host-` prefix, `Secure`/`HttpOnly`/`SameSite=Lax`, be signed/server-side, and bound to the specific `client_id`. |
| **Token passthrough** | Server accepts a token not issued for it and forwards it downstream. | **Explicitly forbidden.** Breaks rate limiting, audit trails, and trust boundaries, and enables exfiltration. |
| **SSRF via OAuth discovery** | Malicious server points `resource_metadata`/`authorization_servers`/AS metadata endpoints at internal URLs (cloud metadata IP, private ranges, `localhost`). | Clients MUST consider SSRF risk; tactics are SHOULD-level: enforce HTTPS (loopback exception), block private/reserved ranges (`10/8`, `172.16/12`, `192.168/16`, `127/8`, `169.254/16`, `fc00::/7`, `fe80::/10`) without hand-rolling IP parsing, validate redirect targets, watch DNS-rebinding/TOCTOU. |
| **Header/body desync** *(new — Streamable HTTP)* | An intermediary routes or rate-limits on the mirrored `Mcp-*` headers while the server executes on the body; if they disagree, policy is enforced on one value and work done on another. | Servers processing the body **MUST** validate every mirrored header against it and reject mismatches with `400` + `-32020`. Intermediaries enforcing policy on those headers **SHOULD** verify `MCP-Protocol-Version` indicates a version that requires this validation, and reject the request otherwise rather than trusting unvalidated headers. See [request-model-and-transports.md](request-model-and-transports.md#required-headers). |
| **Local MCP server compromise** | Malicious startup command in client config (e.g. exfiltrating `~/.ssh/id_rsa`), a malicious payload inside the server, or DNS rebinding to a local HTTP server. | One-click config MUST show the exact untruncated command and require explicit consent; SHOULD sandbox spawned servers and warn on `sudo`/`rm -rf`/sensitive-path access; local servers SHOULD use stdio or restrict HTTP (auth token, Unix domain sockets). |
| **OAuth authorization-URL injection** | Malicious server returns a `javascript:`/`data:`/`file:` URL → XSS/RCE when the client opens it. | Client MUST allow only `http` (loopback)/`https` schemes (allowlist, reject dangerous ones), MUST NOT open URLs via a shell, use CSP, sanitize. |
| **stdio-in-proxy privilege escalation** | Stolen proxy auth token (via XSS) lets an attacker make the proxy spawn arbitrary stdio commands → RCE. | Fix the upstream XSS/URL-scheme issue; sandbox spawned processes. |
| **Elicitation URL phishing** *(documented on the client/elicitation page)* | Alice starts a URL-mode elicitation, tricks Bob into completing it → tokens bind to Alice, giving account takeover. | Server **MUST** ensure the user who started the elicitation is the one who completes it — e.g. point the elicitation at the server's own "connect URL" that checks a session cookie for the same user before forwarding to the third-party AS. Clients MUST NOT pre-fetch/auto-open URL-mode URLs without explicit consent, MUST show the full URL, SHOULD warn on ambiguous/Punycode URIs. |
| **Mix-up attacks / open redirection / localhost redirect impersonation / CIMD trust policies** | Standard OAuth hazards, each with its own section on the security pages. | Exact-match redirect URIs, `iss` validation (above), AS-abuse protection and trust policies for CIMD. Read the source pages before implementing a proxy or an AS. |
| **Scope over-grant** | Publishing omnibus scopes (`*`, `full-access`) instead of granular ones. | Progressive least-privilege scopes with step-up challenges (see incremental consent above). |

**Note what's *gone*:** "Session hijacking" no longer exists as an MCP attack pattern, because
protocol-level sessions don't. If you need it for a legacy-era deployment, the spec keeps it at
`/docs/2025-11-25/tutorials/security/security_best_practices#session-hijacking`.

## Foundational principles

The base spec's non-negotiables, restated because MCP "cannot enforce these at the protocol level" —
implementers must build the actual consent/authorization flows:

- **User consent & control** for data access, tool invocation, and LLM sampling.
- **Data privacy** — hosts MUST get consent before exposing user data, and MUST NOT retransmit resource
  data without consent.
- **Tool safety** — tools can mean arbitrary code execution; require consent before invocation, and
  treat tool descriptions and annotations as **untrusted** unless the server is trusted.
- **Rate limiting** has no dedicated spec section — only scattered SHOULDs (the completion utility's
  debounce/rate-limit advice, plus general abuse-protection framing). Don't go looking for more.

Two hardening rules that live outside the security pages but belong in a threat model: **`$ref` must
not be auto-dereferenced to network URIs**, and **composition keywords must be bounded** — an
unbounded JSON Schema is a DoS vector against your validator. Both in
[primitives.md](primitives.md#architecture).

## Sources (exact URLs fetched, July 2026, `2026-07-28` unless noted)

- https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/index (framework, `iss`/RFC 9207 table)
- https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/client-registration (CIMD priority, DCR deprecation, `application_type`, issuer-keyed credentials)
- https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/authorization-server-discovery
- https://modelcontextprotocol.io/specification/2026-07-28/basic/authorization/security-considerations (normative; note: no "session hijacking" section anymore)
- https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices (the attack catalog, incl. **State Handle Hijacking**)
- https://modelcontextprotocol.io/specification/2026-07-28/client/elicitation (source for the URL-phishing row)
- https://modelcontextprotocol.io/specification/2026-07-28/deprecated (DCR deprecation state)
- `https://modelcontextprotocol.io/specification/2026-07-28/basic/security_best_practices` → **307, no longer exists**

If re-verifying: the auth requirements are now split across four `basic/authorization/*` pages, and the
attack catalog moved under `/docs/<date>/tutorials/security/`. Don't look for
`/specification/<date>/basic/security_best_practices` — it's been retired.
