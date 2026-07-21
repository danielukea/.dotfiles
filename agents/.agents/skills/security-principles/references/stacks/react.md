# Stack Adapter: React / Frontend

Frontend-specific security knowledge — what React guarantees automatically, and
the unsafe/safe code forms for each vulnerability class. Loaded once a
`package.json` with React (or `*.tsx`/`*.jsx`) is detected. For the Rails↔React
seams (CSRF tokens on API calls, token storage, CSP coordination), also load
[cross-stack.md](cross-stack.md).

## What React already guarantees

- **JSX auto-escaping (XSS):** React escapes every value rendered in JSX.
  `{user.field}`, `{comment.text}`, and template-literal children are safe —
  unsafe only via `dangerouslySetInnerHTML`.
- **Router redirects:** `<Navigate to="/safe-path" />` with a hardcoded string is
  safe; only user-controlled `to`/`navigate()` targets are open-redirect vectors.
- **`fetch()` is not SSRF:** the same-origin policy sandboxes browser requests.
  Client-side `fetch(userUrl)` is not SSRF — that requires the *server* to make
  the request.
- **CSP via meta tag:** a `<meta http-equiv="Content-Security-Policy">` tag makes
  CSP active even without an HTTP header — check the HTML template before treating
  CSP as missing.

---

## XSS via dangerouslySetInnerHTML

```jsx
// VULNERABLE — directly injects HTML, XSS if content is user-controlled
<div dangerouslySetInnerHTML={{ __html: user.bio }} />
<div dangerouslySetInnerHTML={{ __html: marked(userMarkdown) }} />  // markdown renderer can output <script>

// Safe
<div>{user.bio}</div>  // React auto-escapes text content

// If HTML rendering is required, sanitize first
import DOMPurify from 'dompurify'
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(user.bio) }} />
```

**Code signals:** Any `dangerouslySetInnerHTML` — unsafe whenever the value can ever contain user-supplied content, even if it looks safe at a glance.

---

## DOM Manipulation without React

```js
// VULNERABLE — bypasses React's escaping
document.getElementById('output').innerHTML = userData
element.innerHTML = `<b>${comment.text}</b>`
document.write(location.search)

// Safe
element.textContent = userData   // sets text, not HTML
```

**Code signals:** `.innerHTML =` with anything that could be user-controlled, `document.write()`, `.insertAdjacentHTML()`.

---

## eval() and Dynamic Code Execution

```js
// VULNERABLE
eval(params.get('code'))
new Function(userInput)()
setTimeout(userString, 100)   // string form executes as code
setInterval(userString, 100)
```

**Code signals:** `eval(`, `new Function(`, string-form `setTimeout`/`setInterval`.

---

## Prototype Pollution

```js
// VULNERABLE — merging user JSON into objects can pollute Object.prototype
_.merge(target, JSON.parse(userInput))
Object.assign(target, userJSON)  // shallow, less dangerous but watch deep merges

// Dangerous payload: {"__proto__": {"isAdmin": true}}

// Safe — use null-prototype objects for untrusted data dictionaries
const dict = Object.create(null)
```

**Code signals:** Deep merge functions (`_.merge`, `deepmerge`, `extend`) with user-controlled source objects.

---

## Token Storage

```js
// VULNERABLE — readable by any XSS on the page
localStorage.setItem('authToken', token)
sessionStorage.setItem('jwt', token)
window.token = token

// Safe — HttpOnly cookie (set by server, not accessible to JS)
// If localStorage is unavoidable, ensure strict CSP and no XSS vectors
```

**Code signals:** `localStorage.setItem` or `sessionStorage.setItem` storing tokens, JWTs, or session identifiers. (The server-vs-client storage decision is a full-stack seam — see [cross-stack.md](cross-stack.md).)

---

## URL Redirect with User Input

```js
// VULNERABLE — open redirect / JavaScript URL injection
window.location.href = params.get('redirect')
window.location.href = `/${userInput}`

// Dangerous input: javascript:alert(1) or https://evil.com
```

**Code signals:** `window.location =`, `window.location.href =`, `window.location.replace(` with user-controlled values. Check if the URL is validated to be relative or same-origin.

---

## Content Security Policy

CSP can be delivered as a meta tag or (better) an HTTP header:
```html
<!-- In HTML meta tag -->
<meta http-equiv="Content-Security-Policy" content="...">
```

A missing or weak CSP dramatically increases XSS impact.

**Weak CSP signals:**
- `script-src *` — allows scripts from anywhere
- `script-src 'unsafe-inline'` without nonce — allows inline scripts
- `script-src 'unsafe-eval'` — allows eval() and similar
- No CSP at all

---

## Third-Party Scripts

```html
<!-- VULNERABLE — no integrity check, if CDN is compromised, attacker controls your page -->
<script src="https://cdn.example.com/lib.js"></script>

<!-- Safe — Subresource Integrity (SRI) -->
<script
  src="https://cdn.example.com/lib.js"
  integrity="sha384-..."
  crossorigin="anonymous"
></script>
```

**Code signals:** External `<script src>` tags without `integrity` attribute.

---

## React Router and Redirects

```jsx
// VULNERABLE — user-controlled redirect destination
const returnTo = new URLSearchParams(location.search).get('returnTo')
<Navigate to={returnTo} />
navigate(returnTo)

// Safe — validate it's a relative path
const isRelative = (url) => url.startsWith('/') && !url.startsWith('//')
if (isRelative(returnTo)) navigate(returnTo)
```

---

## Sensitive Data in State / Redux

**Code signals:**
- Full credit card numbers, SSNs, passwords stored in Redux state or React state (accessible via DevTools)
- Sensitive data in component props that get serialized to localStorage for persistence
- `console.log` statements outputting auth tokens or sensitive user data

---

## postMessage Security

```js
// VULNERABLE — accepts messages from any origin
window.addEventListener('message', (event) => {
  processData(event.data)  // no origin check
})

// Safe
window.addEventListener('message', (event) => {
  if (event.origin !== 'https://trusted-origin.com') return
  processData(event.data)
})
```

**Code signals:** `window.addEventListener('message', ...)` without `event.origin` validation.

---

## Environment Variables / Secrets

```js
// VULNERABLE — exposed to browser bundle
const apiSecret = process.env.REACT_APP_SECRET_KEY
const privateKey = import.meta.env.VITE_PRIVATE_KEY

// In Vite: VITE_ prefix means it's bundled into client code
// In CRA: REACT_APP_ prefix means it's bundled into client code
```

Any secret that must stay private cannot have `REACT_APP_` or `VITE_` prefix — those values end up in the browser bundle. Only public API keys (publishable Stripe key, public analytics ID) should be in frontend env vars.

**Code signals:** `process.env.REACT_APP_*` or `import.meta.env.VITE_*` containing secret keys, private API tokens, or internal URLs.

---

## Dependency Vulnerabilities

Run `npm audit` or `yarn audit` to check for known CVEs in dependencies.

**High-risk package categories to scrutinize:**
- Serialization/parsing libraries (yaml, xml, csv parsers)
- Template engines
- Request/HTTP client libraries
- Authentication libraries (passport, auth0)
- File handling utilities
