# Stack Adapter: Full-Stack (Rails + React)

Security seams that live *between* a Rails backend and a React frontend, belonging
to neither single-stack adapter. Also load [rails.md](rails.md) and
[react.md](react.md). Loaded when both a `Gemfile` and a React frontend are
present.

## CSRF token handoff

Rails emits the CSRF token in a `<meta name="csrf-token">` tag; a cookie-
authenticated SPA must echo it on every state-changing request. The guarantee only
holds if the token actually crosses the seam.

```js
// Required for cookie-auth mutations — omit this and Rails rejects the request
// (or, if CSRF was disabled server-side, the endpoint is CSRF-vulnerable)
fetch('/api/users/1', {
  method: 'DELETE',
  headers: {
    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
  }
})
```

**Code signals:** POST/PUT/PATCH/DELETE to a cookie-authenticated Rails endpoint
without the `X-CSRF-Token` header — or a Rails controller that dropped
`verify_authenticity_token` to make the SPA "work" (moves the vulnerability
server-side rather than fixing it).

## Session-token storage decision

Where the session token lives is a joint decision, and the safe answer spans both
stacks: the **server** sets an `HttpOnly; Secure; SameSite` cookie so the token is
never reachable from JavaScript. Storing it in React `localStorage`/`sessionStorage`
(see [react.md](react.md#token-storage)) trades that guarantee away — any XSS on
the page can read it.

**Code signals:** a React app persisting an auth token client-side *while* the
Rails backend is capable of setting an HttpOnly cookie — the cookie path is
strictly safer.

## CSP coordination

CSP is only as strong as the weaker of the two stacks. A strict Rails-emitted
policy is undone by a React build that injects inline scripts/styles, and a React
`<meta>` CSP can be overridden by a permissive Rails response header.

**Code signals:** `'unsafe-inline'`/`'unsafe-eval'` added to accommodate a bundler
or inline `<style>`; a Rails CSP initializer and a React meta-tag CSP that
disagree; nonces generated server-side but not threaded through to React-rendered
`<script>` tags.
