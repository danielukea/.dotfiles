# Framework & Library Mitigations

What Rails, React, and common libraries handle automatically — use this to identify false positives in security findings.

---

## Rails Automatic Mitigations

### HTML Escaping (XSS)

Rails ERB templates **auto-escape all output by default**. The following patterns are safe:

```erb
<%= user.name %>           # safe — auto-escaped
<%= @post.title %>         # safe — auto-escaped
<p><%= content %></p>      # safe — auto-escaped
```

Flag as unsafe ONLY when the developer explicitly opts out:
```erb
<%= raw(user.bio) %>                  # unsafe — explicitly bypasses escaping
<%= user.bio.html_safe %>             # unsafe — marks string as trusted
<%= content_tag(:div, user.bio, escape: false) %>  # unsafe
```

**False positive signal:** Flagging `<%= user.field %>` as XSS without a corresponding `html_safe`/`raw()` call.

---

### SQL Injection (ActiveRecord)

ActiveRecord parameterizes queries automatically when using the hash/array form:

```ruby
# SAFE — parameterized by ActiveRecord
User.where(name: params[:name])
User.where(email: params[:email], active: true)
User.find_by(token: params[:token])
User.where("created_at > ?", params[:date])   # array form is safe
```

Only flag when developer constructs raw SQL strings with interpolation:
```ruby
User.where("name = '#{params[:name]}'")    # unsafe
User.order("#{params[:col]} ASC")          # unsafe — order() doesn't parameterize strings
```

**False positive signal:** Flagging `User.where(field: params[:val])` as SQL injection.

---

### CSRF Protection

`ActionController::Base` includes CSRF protection by default via `protect_from_forgery`. All non-GET requests require a CSRF token unless explicitly disabled.

Safe patterns:
```ruby
class ApplicationController < ActionController::Base
  # protect_from_forgery is on by default — no action needed
end
```

`skip_before_action :verify_authenticity_token` is a **genuine finding** — but investigate why it's there. API controllers using token auth (Bearer) legitimately skip CSRF because they don't use cookies. The skip is only a vulnerability when the endpoint is cookie-authenticated.

**False positive signal:** Flagging CSRF skip on a controller that uses `before_action :authenticate_api_user!` with Bearer tokens.

---

### Mass Assignment (Strong Parameters)

Rails 4+ requires explicit `permit()` calls. `ActionController::Parameters` objects are not assignable without permitting, so simply passing `params[:user]` to `.new()` or `.update()` raises a `ForbiddenAttributesError` — it doesn't silently assign all fields.

```ruby
# Will raise ForbiddenAttributesError at runtime, not silently assign
User.new(params[:user])  # actually safe in Rails 4+ — but bad practice, flag as low
```

The genuine vulnerability is `params.require(:user).permit!` which bypasses the protection.

**False positive signal:** Flagging `User.new(params[:user])` as mass assignment in a Rails 4+ app as critical/high — it raises an error rather than assigning. Still flag as medium (will crash rather than silently set fields, but should use permit).

---

### Session Cookie Security

When using `config.force_ssl = true` (common in production), Rails automatically sets `Secure` on cookies. The `session_store` configuration sets `HttpOnly` by default.

```ruby
# config/environments/production.rb
config.force_ssl = true   # implies Secure on all cookies
```

**False positive signal:** Flagging missing `Secure` flag on cookies when `config.force_ssl = true` is set.

---

### Content Security Policy

Rails 6+ ships with a CSP DSL (`config/initializers/content_security_policy.rb`). Check if it exists before flagging missing CSP.

```ruby
# config/initializers/content_security_policy.rb — if present, CSP is configured
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  # ...
end
```

**False positive signal:** Flagging missing CSP header when `content_security_policy.rb` initializer exists.

---

### HSTS

`config.force_ssl = true` enables HSTS automatically in Rails. Don't flag missing HSTS separately when this is set.

---

### Brakeman Known Patterns

Brakeman (Rails security scanner) reports many patterns. Some common Brakeman warnings that are often false positives:

- **"Possible SQL injection"** on `order(params[:sort])` — flagged even when sort column is validated against an allowlist in the same method
- **"Cross-site scripting"** on `link_to` with a URL — safe if the URL is from `url_for` or a route helper, not user input
- **"Session setting"** warnings when `reset_session` is called correctly

When these appear, check whether there's an allowlist or sanitization step nearby that Brakeman missed.

---

## React / JavaScript Automatic Mitigations

### JSX Auto-Escaping (XSS)

React **escapes all values rendered in JSX by default**:

```jsx
// ALL of these are safe — React escapes text content
<div>{user.name}</div>
<p>{comment.text}</p>
<span>{`Hello ${user.name}`}</span>
```

Only flag when developer explicitly bypasses escaping:
```jsx
<div dangerouslySetInnerHTML={{ __html: content }} />   // unsafe
```

**False positive signal:** Flagging `{user.field}` in JSX as XSS.

---

### React Router Redirects

`<Navigate to="/safe-path" />` with a hardcoded string is safe. Only flag when the `to` prop comes from user-controlled data without validation.

---

### fetch() and CORS

The browser's same-origin policy blocks cross-origin `fetch()` responses unless the server explicitly permits them via CORS headers. Client-side `fetch()` to a third-party URL is not an SSRF vector — SSRF requires the **server** to make the request. Browser-side fetches are restricted by the browser sandbox.

**False positive signal:** Flagging client-side `fetch(userUrl)` in React as SSRF — SSRF only applies to server-side code.

---

### Content Security Policy via meta tag

If the app has a `<meta http-equiv="Content-Security-Policy">` tag, CSP is active even without an HTTP header. Check the HTML template before flagging missing CSP.

---

## Common Library Mitigations

### Devise (Rails Authentication)

Devise handles many auth security concerns out of the box:
- **Password hashing:** bcrypt by default (`devise :database_authenticatable` uses bcrypt)
- **Session regeneration:** Devise calls `reset_session` on sign-in/sign-out
- **Token expiry:** `confirmable`, `recoverable` modules handle token TTL
- **Brute force:** `lockable` module provides account lockout

**False positive signals:**
- Flagging password storage as weak when Devise's `database_authenticatable` is in use (it's bcrypt)
- Flagging missing `reset_session` on login when Devise handles sign-in (it calls it internally)
- Flagging password reset tokens as non-expiring when `config.reset_password_within` is set

Always check `config/initializers/devise.rb` for Devise configuration before flagging auth issues.

---

### Pundit / CanCanCan (Authorization)

If the app uses Pundit or CanCanCan with `before_action :authenticate_user!` and policy/ability checks:

- `ApplicationController` with `after_action :verify_authorized` (Pundit) — every action is checked
- `load_and_authorize_resource` (CanCanCan) — automatically scopes and authorizes

**False positive signal:** Flagging `Model.find(params[:id])` as IDOR when `load_and_authorize_resource` is active in that controller or `ApplicationController`.

---

### Rack::Attack (Rate Limiting)

If `Rack::Attack` is configured in `config/initializers/rack_attack.rb`, rate limiting may already cover the endpoints being flagged.

**False positive signal:** Flagging missing rate limiting on `/users/sign_in` when Rack::Attack config throttles it.

---

### SecureHeaders Gem

If `SecureHeaders` gem is present (`gem 'secure_headers'` in Gemfile), it adds security headers (CSP, HSTS, X-Frame-Options, X-Content-Type-Options, X-XSS-Protection) automatically.

**False positive signal:** Flagging missing security headers when `secure_headers` gem is installed and configured.

---

## Guidance for the False Positive Reviewer

When reviewing a finding, ask:

1. **Is the value actually user-controlled?** Many patterns look dangerous but operate on hardcoded or server-controlled values (e.g., `"admin".html_safe` vs `params[:name].html_safe`).

2. **Does the framework handle this automatically?** Check the list above for the detected stack.

3. **Is there a library/initializer that already mitigates this?** Look for Devise, Pundit, CanCanCan, Rack::Attack, SecureHeaders, CSP initializers.

4. **Is the code in a test file?** Security rules are relaxed for test fixtures, factories, and spec files — `User.create(admin: true)` in a factory is not mass assignment.

5. **Is the "dangerous" method called on a constant or I18n string?** `I18n.t('welcome').html_safe` is safe because translation strings are developer-controlled, not user-controlled.

When dismissing a finding, explain specifically why it's a false positive — don't just say "framework handles it." Name the mechanism (e.g., "Devise calls `reset_session` during sign-in, so this is handled at `app/controllers/application_controller.rb` via `devise_for`").
