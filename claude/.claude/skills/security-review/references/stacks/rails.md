# Rails Security Patterns

Rails-specific vulnerabilities and code patterns to look for during security review.

---

## Strong Parameters / Mass Assignment

```ruby
# VULNERABLE — never do this
User.new(params[:user])
user.update(params)
User.create(params.require(:user))   # require alone doesn't filter fields

# Safe
User.new(params.require(:user).permit(:name, :email))

# CRITICAL — exposes every attribute including role, admin, account_id
params.require(:user).permit!
```

**Look for:** `.permit!`, `update(params)`, `new(params[:model])` without permit list, params passed directly to `create`/`update_attributes`.

---

## SQL Injection in ActiveRecord

```ruby
# VULNERABLE
User.where("name = '#{params[:name]}'")
User.where("role = #{role}")                          # even without quotes
User.find_by_sql("SELECT * FROM users WHERE id = #{id}")
User.order("#{params[:sort]} #{params[:direction]}")  # order clause injection
User.group(params[:group_by])

# Safe
User.where(name: params[:name])
User.where("role = ?", role)
User.order(created_at: :desc)                         # allowlist sort columns
```

**Look for:** String interpolation in `.where()`, `.order()`, `.group()`, `.having()`, `.joins()`, `.select()`, `.find_by_sql()`, raw `execute()`.

---

## Command Injection

```ruby
# VULNERABLE
`git log #{params[:branch]}`
system("convert #{params[:file]} output.png")
IO.popen("grep #{user_query} /data/file")

# Safe
system("git", "log", "--", branch_name)  # array form, no shell interpolation
```

---

## XSS / HTML Injection

```ruby
# VULNERABLE — marks string as HTML-safe without escaping
"<b>#{user.bio}</b>".html_safe
raw(user.description)
render inline: "<%= #{params[:template]} %>"
content_tag(:div, user.input, escape: false)

# Safe
h(user.bio)              # explicit escape
ERB::Util.html_escape()  # same
# Rails auto-escapes by default in templates — unsafe only when using html_safe/raw
```

**Look for:** `.html_safe` on user-controlled values, `raw()` helper, `render inline:` with params, `escape: false` on content helpers.

---

## CSRF

```ruby
# VULNERABLE
class ApiController < ApplicationController
  skip_before_action :verify_authenticity_token  # if using cookies for auth, this is dangerous

# Also check
protect_from_forgery with: :null_session  # disables CSRF completely
```

For cookie-authenticated APIs, CSRF is required. For token-authenticated (Bearer), skipping is OK but must verify the token is actually validated.

---

## Session Security

```ruby
# Check for session regeneration on login
def create
  # VULNERABLE — no session reset
  session[:user_id] = user.id

  # Safe — regenerates session ID to prevent fixation
  reset_session
  session[:user_id] = user.id
end

# Check logout
def destroy
  reset_session   # must clear all session data
  redirect_to root_path
end
```

**Look for:** Login action missing `reset_session` before setting session data. Logout missing `reset_session`.

---

## Authorization / Access Control

```ruby
# VULNERABLE — finds any record, not scoped to current user
@document = Document.find(params[:id])

# Safe — scoped to current user
@document = current_user.documents.find(params[:id])
# or
@document = Document.find(params[:id])
authorize! :read, @document   # CanCanCan
policy(@document).show?       # Pundit
```

**Look for:** `Model.find(params[:id])` at top of actions without subsequent authorization check, missing `before_action :authenticate_user!` or `before_action :authorize!`, admin-only actions without role check.

---

## File Upload Security

```ruby
# VULNERABLE
file_path = Rails.root.join('public', params[:filename])  # path traversal
File.write(file_path, params[:content])

# Also watch for
send_file params[:path]                   # arbitrary file read
File.read(params[:filename])              # arbitrary file read
`cat #{params[:file]}`                    # command injection + file read
```

**Check:** File type validation (extension AND magic bytes), storage outside public/ directory, no direct execution of uploaded files, virus scanning for sensitive apps.

---

## Deserialization

```ruby
# CRITICAL — arbitrary code execution
Marshal.load(untrusted_data)
YAML.load(params[:config])        # CVE-exploitable in older Ruby

# Safe
YAML.safe_load(params[:config])   # restricts to safe types
JSON.parse(params[:data])         # JSON is safe
```

**Look for:** `Marshal.load`, `YAML.load` (not `.safe_load`), `.load` on any serialization library with user input.

---

## Secrets & Configuration

**Look for:**
- API keys, tokens, passwords in `config/` files checked into git
- `ENV.fetch('KEY', 'hardcoded_default')` where default is a real secret
- `Rails.application.credentials` used correctly vs. hardcoded alternatives
- Secrets in log statements: `Rails.logger.info "Token: #{token}"`

---

## Open Redirect

```ruby
# VULNERABLE
redirect_to params[:return_to]
redirect_to params[:redirect_url]

# Safe
if valid_return_url?(params[:return_to])
  redirect_to params[:return_to]
else
  redirect_to root_path
end

# valid_return_url? should check it's a relative path or matches allowed hosts
```

---

## Devise-Specific

- `config.password_length` — should be 8+ minimum
- `config.lock_strategy` — should be `:failed_attempts` (not `:none`)
- `config.maximum_attempts` — should be set
- `config.unlock_strategy` — check for email vs. time
- `config.reset_password_within` — should be short (15 min - 2 hours)
- `config.timeout_in` — should be configured for sensitive apps
- `config.expire_auth_token_on_timeout` — should be `true`
- `config.send_password_change_notification` — should be `true`

---

## Rate Limiting (Rack::Attack)

**Look for absence of rate limiting on:**
- `POST /sessions` (login)
- `POST /passwords` (password reset request)
- `GET /passwords/edit` (reset token consumption)
- Any endpoint accepting user-generated content at scale
- API endpoints without authentication

---

## Timing Attacks

```ruby
# VULNERABLE — string comparison short-circuits, leaks info via timing
if params[:token] == stored_token

# Safe — constant-time comparison
if ActiveSupport::SecurityUtils.secure_compare(params[:token], stored_token)
```

**Look for:** `==` comparisons of security tokens, API keys, signatures, HMAC values.
