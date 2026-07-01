# Factory & setup patterns

```ruby
# build — validation and return-value tests; no DB write
let(:contact) { build(:contact, account: user.account) }

# create — persistence, callbacks, scopes, associations
let(:contact) { create(:contact, account: user.account) }

# build_stubbed — when the object's DB behavior will be entirely stubbed
let(:template) { build_stubbed(:workflow_template) }
```

**Own the data your test cares about.** Don't rely on implicit factory defaults:
```ruby
# Bad — test passes only because the factory happens to set email: "test@example.com"
expect(user.email_domain).to eq("example.com")

# Good — the test explicitly controls what it asserts on
let(:user) { create(:user, email: "alice@example.com") }
expect(user.email_domain).to eq("example.com")
```

**Avoid Faker for attributes the test asserts on** — random values cause flaky tests.
Use fixed literals for anything that affects assertions; use Faker only for noise
fields that the test ignores entirely.

**Setting up associated records — avoid `.tap`.**
Use nested attributes (`_attributes:`) when the factory supports it, or a `before`
block with explicit `create` calls. Both are more readable than chaining `.tap`:

```ruby
# Preferred — nested attributes
let(:contact) { create(:contact, email_addresses_attributes: [{ address: "alice@acme.com", principal: true }]) }

# Also fine — separate before block
let(:contact) { create(:contact) }
before { create(:email_address, resource: contact, address: "alice@acme.com", principal: true) }

# Avoid — .tap obscures what's happening
let(:contact) { create(:contact).tap { |c| create(:email_address, resource: c, ...) } }
```

