## Role

You are validating a working prototype end-to-end. Your job is to confirm each outcome works by **visually verifying it in the browser**, and if it doesn't, **fix it using TDD**.

## Workflow Per Step

```
1. VERIFY — Use agent-browser to visit the page / perform the action
2. SCREENSHOT — Capture evidence of the current state
3. PASS? — Does it match the expected outcome described in the plan?
   ├── YES → Mark step done, move on
   └── NO → Enter FIX mode (below)
```

### FIX Mode (TDD)

When a step fails verification:

1. **Investigate**: Read the relevant controller, model, view, or React component. Check browser console errors, network responses, and server logs.
2. **Write a failing test** that captures the broken behavior:
   - Ruby: `bin/wealthbox rspec <spec>` (NEVER use `bin/wealthbox exec` for rspec)
   - JS: `yarn jest <spec> --no-coverage`
3. **Confirm the test fails** (red) for the right reason.
4. **Fix the code** to make the test pass (green).
5. **Lint** changed files:
   - Ruby: `bin/wealthbox exec bundle exec rubocop -a <files>`
   - JS: `yarn eslint <files> --fix`
6. **Re-verify visually** with agent-browser — screenshot again.
7. Only mark done when the visual check AND tests pass.

## Browser Commands

Use `agent-browser` CLI for all browser interactions:

```bash
agent-browser open <url>                    # Navigate to URL
agent-browser screenshot <path>             # Capture screenshot
agent-browser click <selector>              # Click an element
agent-browser type <selector> <text>        # Type into a field
agent-browser wait <selector>               # Wait for element to appear
```

Save all screenshots to `.context/screenshots/` with descriptive names like `02-login-page.png`, `08-test-fire-success.png`.

## Environment

**IMPORTANT: Resolve the base URL dynamically. Do NOT hardcode it.**

Run `bin/wealthbox status` at the start of every iteration to get:
1. The **base URL** (e.g., `https://valencia-v1.wealthbox.local` or similar — it varies per worktree)
2. The **mode** (Docker or native) — determines the webhook URL the Node server is reachable at

```bash
# First thing every iteration:
bin/wealthbox status
```

Use the URL from the status output for ALL browser navigation. Never assume `crm-web.wealthbox.local`.

- **Base URL**: Get from `bin/wealthbox status` (DO NOT HARDCODE)
- **Node webhook server**: `http://localhost:4000` (partner-integration-prototype)
- **Node webhook secret**: `dev_secret_change_me`
- **Dev portal login**: `bill@patriot.com` / `Gotham10`
- **Partner slug**: `dev-partner`
- **CRM password**: `Gotham10` (never change this)
- **Feature flag**: `ai-integrations:partner_tools:2026_03`
- **Seed**: `bin/wealthbox exec bundle exec rails runner db/seeds/development/partner_plugin.rb`

For webhook URL in plugin config (what the CRM posts to when test-firing):
- Docker mode: `http://host.docker.internal:4000/webhook`
- Native mode: `http://localhost:4000/webhook`

Determine which from `bin/wealthbox status` output.

## Data Setup

Before any browser verification, ensure the data each step needs exists. Use `bin/wealthbox runner` to create or verify records. **Do not rely on seeds already being run** — each iteration starts with a fresh context and must be self-sufficient.

### Bootstrap (run at the start of every iteration)

```bash
# 1. Ensure seed data exists (idempotent — safe to re-run)
bin/wealthbox exec bundle exec rails runner db/seeds/development/partner_plugin.rb

# 2. Ensure feature flag is enabled
bin/wealthbox runner "FeatureFlag.enable('ai-integrations:partner_tools:2026_03')"

# 3. Ensure plugin webhook points to the Node server (not httpbin)
bin/wealthbox runner "
  mode = ENV['WB_MODE'] || 'docker'
  host = mode == 'native' ? 'localhost' : 'host.docker.internal'
  plugin = Plugin.find_by(namespace: 'dev_tools')
  if plugin
    plugin.update!(webhook_url: \"http://#{host}:4000/webhook\", webhook_secret: 'dev_secret_change_me')
    puts \"Plugin webhook: #{plugin.webhook_url}\"
  else
    puts 'ERROR: dev_tools plugin not found — seed may have failed'
  end
"

# 4. Verify Node server is reachable
curl -sf http://localhost:4000/health || echo "WARNING: Node server not running on port 4000"
```

### Creating data for specific steps

When a step needs data that doesn't exist yet (e.g., a connection, a tool override, a new tool), create it via `bin/wealthbox runner` with Ruby one-liners. Examples:

```bash
# Create a connection for the firm
bin/wealthbox runner "
  plugin = Plugin.find_by!(namespace: 'dev_tools')
  account = User.find_by!(email: 'bill@patriot.com').account
  conn = Plugin::Connection.find_or_create_by!(plugin: plugin, account: account) do |c|
    c.auth_method = 'api_key'
  end
  conn.update!(active: true)
  puts \"Connection #{conn.id}: active=#{conn.active}\"
"

# Check tools_for output
bin/wealthbox runner "
  user = User.find_by!(email: 'bill@patriot.com')
  tools = Composer::Plugin.tools_for(user)
  puts \"#{tools.size} tools: #{tools.map(&:name).join(', ')}\"
"

# Disconnect (for teardown steps)
bin/wealthbox runner "
  plugin = Plugin.find_by!(namespace: 'dev_tools')
  account = User.find_by!(email: 'bill@patriot.com').account
  Plugin::Connection.where(plugin: plugin, account: account).update_all(active: false)
  puts 'Disconnected'
"
```

Always verify data state before and after browser actions — don't trust the UI alone for data mutations.

## Rules

- **Never skip verification.** Every step must have a screenshot proving it works.
- **Never mark done without visual confirmation.** A passing test alone is not enough — you must see it in the browser.
- **Fix forward, don't work around.** If a page is broken, fix the actual code. Don't bypass with curl/API calls to pretend it works.
- **One step at a time.** Complete and verify one plan step before moving to the next.
- **Commit after each fix.** If you changed code to fix a broken step, commit before moving on.
- **Don't change the Node server.** The partner-integration-prototype is the reference — the CRM code adapts to it, not the other way around.
- **Don't change dev passwords.** Always `Gotham10`.
