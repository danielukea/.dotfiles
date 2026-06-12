---
name: write-tests
description: >
  Write and review high-quality, non-tautological RSpec tests for this Rails
  codebase. Use this skill whenever writing new tests, adding specs to existing
  code, reviewing tests for quality issues, doing TDD, or when a user says "write
  a spec", "add tests", "TDD this", "review these tests", "are these tests
  good?", or "check my specs". Also use proactively whenever implementing any
  feature or fix — tests should come first. Covers model specs, request specs,
  command/service specs, job specs, and shared examples following this codebase's
  exact conventions.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# Write Tests

Write and review RSpec tests that are behavior-driven, non-tautological, and
follow this codebase's conventions.

---

## The Core Test Discriminator

A test is valuable only when it satisfies **both** conditions simultaneously:

1. **It fails when the implementation is wrong** — it would fail against a method
   that returns `nil`, a missing DB constraint, or a broken scope.
2. **It survives a correct refactor** — renaming an internal method, reorganizing
   private helpers, or extracting a collaborator should not break the test.

Tautological tests fail #1 (they pass against broken code). Change-detector tests
fail #2 (they shatter on harmless internal changes). Both are false confidence.

---

## Tautological Patterns — Avoid These

These tests look like coverage but provide none:

### ❌ Testing association declarations
```ruby
# Just checks that has_many :students appears in the source file
it { is_expected.to have_many(:students) }
```
Test the **behavior** the association enables instead:
```ruby
it "includes the student in the classroom's roll" do
  student = create(:student, classroom: classroom)
  expect(classroom.students).to include(student)
end
```
Exception: `have_many` / `belong_to` one-liners from shoulda-matchers are acceptable
as lightweight smoke coverage for plain associations — but don't substitute them for
behavioral tests when the association has options (`dependent: :destroy`, `through:`,
counter cache) that can actually break.

### ❌ Testing method presence
```ruby
it { expect(user).to respond_to(:full_name) }
```
Test what the method does, not that it exists.

### ❌ Testing callbacks exist
```ruby
it { expect(user).to callback(:send_welcome_email).after(:create) }
```
Test the observable result: was the email delivered? Did the job enqueue?

### ❌ Testing database schema
```ruby
it { expect(user).to have_db_column(:email).of_type(:string) }
```
Schema facts belong in migrations and `schema.rb`. Test behavior that depends on
that column, not the column's existence.

### ❌ Expected value derived from the implementation
```ruby
# If the implementation formula is wrong, both sides are wrong
expected = (order.subtotal * 0.08).round(2)
expect(order.tax).to eq(expected)
```
Use literals derived from the specification:
```ruby
# From the spec: 8% of $100.00 = $8.00
order = build(:order, subtotal: 100.00)
expect(order.tax).to eq(8.00)
```

### ❌ Stub that tests itself
```ruby
allow(user).to receive(:full_name).and_return("Jane Smith")
expect(user).to have_received(:full_name)
```
This proves nothing about `user` — it proves the stub mechanism works.

---

## High-Value Patterns — Use These

### Assert observable outcomes, in priority order

1. **Persisted state** — `change { Model.count }`, `change { record.reload.attribute }`
2. **Return value** — `eq`, `be_a`, `include`, `contain_exactly`
3. **Raised exception** — `raise_error(ErrorClass, /message/)`
4. **Side effects** — `have_enqueued_job`, `have_sent_email`, `have_received` on a
   real boundary (mailer, job, external service)

### `change { }` is the highest-density assertion for Rails

```ruby
it "marks the step complete and advances the workflow" do
  expect { command.perform }
    .to change { step.reload.completed_at }.from(nil)
    .and change { workflow.reload.active_step }.to(next_step)
end
```

One `expect` block, two state changes verified from a single action. This pattern
forces you to say exactly what moves — which is the whole job.

### Always include the "should not" side for scopes and filters

A scope test with only matching records cannot catch a query that returns everything:

```ruby
describe ".active" do
  let!(:active) { create(:user, state: :active) }
  let!(:archived) { create(:user, state: :archived) }  # must exist to prove exclusion

  it "returns only active users" do
    expect(User.active).to contain_exactly(active)
  end
end
```

### Test boundary conditions, not just the happy path

For every happy-path test, ask: what happens when the input is nil? empty? out of
range? from a different account? For every success case, there's an error case.

### Test semantic invariants

A semantic invariant is a rule that must hold *no matter what inputs or state the
system is in* — not subject to policy choices or implementation details. These are
the highest-value test targets because they catch entire classes of bug at once.

Ask: *what must always be true, no matter what?* Those become your most important tests.

```ruby
describe "#email_domain" do
  # Semantic invariant: never raises — always returns a String or nil
  [nil, "", "notanemail", "user@", "alice@acme.com"].each do |email|
    it "does not raise for email #{email.inspect}" do
      contact = build(:contact, email: email)
      expect { contact.email_domain }.not_to raise_error
    end
  end
end
```

Business-rule invariants are especially important:
```ruby
# Invariant: a debit can never exceed the account balance
it "never results in a negative balance" do
  transfer = build(:transfer, amount: account.balance + 1)
  expect { transfer.execute! }.to raise_error(InsufficientFunds)
  expect(account.reload.balance).to be >= 0
end
```

### Data-driven testing for multiple input/output pairs

When a method maps a fixed set of inputs to known outputs, a data table is clearer than
N near-identical context blocks and harder to miss when adding a new case:

```ruby
describe "#priority_label" do
  {
    3 => "High",
    2 => "Medium",
    1 => "Low",
    nil => nil
  }.each do |priority, label|
    it "returns #{label.inspect} for priority #{priority.inspect}" do
      task = build(:task, priority: priority)
      expect(task.priority_label).to eq(label)
    end
  end
end
```

Use a hash (or array of pairs) when: the same method, N inputs, N expected outputs.
Don't use it when each case needs different setup or assertions — write them explicitly.

### Describe behavior, not method names

```ruby
# Bad — describes what the code does internally
it "calls #process_payment"

# Good — describes the observable consequence
it "marks the invoice as paid and enqueues the receipt email"
it "returns false when the account balance is insufficient"
```

Context lines complete the sentence begun by `it`. Read them together:
*"when the account is suspended, it returns an empty collection."*

---

## Message-Direction Heuristic

When deciding *where* an assertion belongs, ask: who is the **receiver** of this message?

**The receiver's spec owns the assertion.** If your subject calls `account.users.active` internally, the `User` model spec already asserts what that returns. Adding that same assertion inside the subject's spec doesn't increase coverage — it increases coupling. A change to `User` now breaks two specs for no additional safety.

As the *sender*, you assert only the **visible outcome you produced**, not the internal behavior of your collaborators.

```ruby
# A command that assigns a user and enqueues a notification
class Tasks::AssignCommand
  def perform
    task.update!(assignee: user)         # side effect — yours to assert
    NotificationJob.perform_later(task)  # outgoing command — yours to assert
    task.assignees.count                 # outgoing query — Task model spec owns this
  end
end

# Good — assert what this command is responsible for
it "updates the assignee" do
  expect { command.perform }.to change { task.reload.assignee }.to(user)
end

it "enqueues the notification" do
  expect { command.perform }.to have_enqueued_job(NotificationJob).with(task)
end

# Avoid — this duplicates the Task model spec, adds coupling, adds nothing
it "reflects the new assignee count" do
  command.perform
  expect(task.assignees.count).to eq(1)
end
```

**The corollary:** outgoing query stubs that immediately assert themselves are tautological. If you `allow(service).to receive(:count).and_return(5)` and then assert `expect(service).to have_received(:count)`, you've proved the stub mechanism works — not your code. Either assert the real side effect, or delete the stub assertion entirely.

**What belongs where:**

| What happened | Who asserts it |
|---|---|
| My method's return value | My spec |
| My method changed state | My spec (via `change { record.reload.attr }`) |
| I enqueued a job / sent mail | My spec (`have_enqueued_job`, `have_sent_email`) |
| A collaborator's return value | The collaborator's own spec |
| What the enqueued job *does* | The job's own spec |

---

## describe / context / it Structure

```ruby
describe ClassName do               # top-level: always the class constant
  describe "#method_name" do        # instance method
    context "when <condition>" do   # starts with when/with/without
      it "does the expected thing"  # observable outcome, present tense
      end
    end
  end

  describe ".class_method" do       # class method uses .
    context "without <thing>" do
    end
  end
end
```

- `describe` → what is being tested (class or method)
- `context` → the condition or state variation ("when X is nil", "with a paid plan", "without authorization")
- `it` → the observable outcome in third-person present tense ("creates a record", "raises ArgumentError", "redirects to root")
- Never start `it` descriptions with "should" — say what it *does*, not what it *should* do

---

## subject / let / let!

```ruby
# Named subject — use when the body refers to the object
subject(:command) { described_class.new(workflow, step) }

# let — lazy, cached per-example; default for inputs and collaborators
let(:user) { create(:user, account: account) }

# let! — eager; use ONLY when the record must exist in the DB before the
#         example runs (e.g., scope tests that need an excluded record)
let!(:archived_user) { create(:user, state: :archived) }
```

Use `let` over `before` for anything the test body might inspect. Use `before` for
side effects only: setting `Current.user`, stubbing a dependency, toggling a flag.

**Never assign variables in `before` blocks that the spec then asserts on** — that
variable belongs in a named `let`.

---

## Mocking & Stubbing

Mock what you **don't own** (external services, mailers, jobs). Use real objects for
what you **do own** (your own domain models and service objects).

```ruby
# Setup stub — allow pattern
allow(StripeGateway).to receive(:charge).and_return(stripe_response)

# Assertion — spy style (prefer over expect(...).to receive before the action)
expect(WelcomeMailer).to have_received(:deliver_later)

# Verifying doubles — catch interface drift
let(:mailer) { instance_double("WelcomeMailer", deliver_later: true) }
```

Avoid stubs on your own domain objects (models, commands, services you own) — use real collaborators instead. Stubs on owned code are a signal the subject is doing too much or the test is at the wrong level.

- Enable `verify_partial_doubles` (already configured in this repo)
- Use `instance_double("ClassName")` with string names for classes that may not be loaded
- Use `have_received` (after the action) rather than `expect(...).to receive` (before) — it reads as verification, not prescription

---

## Factory Patterns

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

---

## Spec Type Guide

### Model specs

```ruby
# Structural coverage — one-liners for plain validations/associations
it { is_expected.to validate_presence_of(:name) }
it { is_expected.to belong_to(:account) }

# Behavioral coverage — needed for conditional validations, options, messages
describe "#archive!" do
  context "when the contact has open tasks" do
    let!(:task) { create(:task, contact: contact) }

    it "does not archive and returns false" do
      expect(contact.archive!).to be(false)
      expect(contact).not_to be_archived
    end
  end
end
```

Never mock the model in its own spec — use real objects and real DB interactions.

### Request specs

```ruby
before do
  Current.user = user
  login_with user          # Warden; needed for actual HTTP requests
end

it "creates the record and returns 201" do
  expect {
    post contacts_path, params: { contact: { name: "Jane" } }, as: :json
  }.to change { Contact.count }.by(1)

  expect(response).to have_http_status(:created)
  expect(response.parsed_body["name"]).to eq("Jane")
end

it "returns 422 with validation errors" do
  post contacts_path, params: { contact: { name: "" } }, as: :json
  expect(response).to have_http_status(:unprocessable_entity)
  expect(response.parsed_body["errors"]["name"]).to be_present
end
```

Always assert both the **status code** and the **response body shape**. Don't use
`assigns(:variable)` — it tests internal controller state, not observable HTTP output.

**Inline request params — don't over-extract to `let`.**
A `let` is only justified if the test body needs to reference the variable. Params used
only in the request call belong inline:

```ruby
# Bad — params extracted to lets that the assertions never reference
let(:valid_params) { { contact: { first_name: "Jane", last_name: "Smith", type: "Person" } } }
it "creates the contact" do
  expect { post contacts_path, params: valid_params, as: :json }.to change { Contact.count }.by(1)
end

# Good — inline params; only the response and DB state are asserted
it "creates the contact" do
  expect {
    post contacts_path, params: { contact: { first_name: "Jane", last_name: "Smith", type: "Person" } }, as: :json
  }.to change { Contact.count }.by(1)
  expect(response).to have_http_status(:ok)
end
```

Test the **behavior that belongs to the request layer** — auth, routing, response shape,
and persistence side effects. Don't exhaustively re-test every model validation in request
specs; those belong in model specs.

Cross-account isolation is a required test for any endpoint that scopes by account:
```ruby
context "when the resource belongs to a different account" do
  let(:other_contact) { create(:contact, account: create(:account)) }

  it "returns 404" do
    get contact_path(other_contact)
    expect(response).to have_http_status(:not_found)
  end
end
```

### Command / service specs

```ruby
subject(:command) { described_class.new(workflow, step) }

describe "#perform" do
  it "transitions the workflow to the next step" do
    expect { command.perform }
      .to change { workflow.reload.active_step }.to(next_step)
  end

  context "when the step has no successor" do
    it "marks the workflow as complete" do
      expect { command.perform }
        .to change { workflow.reload.completed? }.to(true)
    end
  end
end
```

Test return value, state changes, and enqueued side effects — not internal call chains.

### Job specs

Separate the "does it enqueue?" test from the "does it do the right thing?" test:

```ruby
it "enqueues the cleanup job after archiving" do
  expect { contact.archive! }.to have_enqueued_job(ArchiveCleanupJob).with(contact.id)
end

it "deletes the exports when performed" do
  create_list(:export, 3, contact: contact)
  expect { ArchiveCleanupJob.perform_now(contact.id) }
    .to change { Export.where(contact: contact).count }.to(0)
end
```

---

## Codebase-Specific Rules (crm-web)

- **`require "spec_helper"`** — there is no `rails_helper` in this repo
- **No feature or system specs** (`spec/features/`, `spec/system/`) — too slow, too flaky
- **Run tests**: `bin/wealthbox rspec spec/path/to_spec.rb` — never bare `rspec` or `bundle exec rspec`
- **`Current.user = user`** in `before` blocks for model/command/lib specs; `login_with user` for request specs
- **Feature flags**: `enable_feature_flag("team:flag:YYYY_MM")` helper (from `Common::FeatureFlagHelpers`); `FeatureWhitelist.toggle_whitelist(user, "Feature Name")` for whitelists
- **VCR**: network calls are auto-recorded/replayed per spec type; use `skip_vcr: true` to opt out
- **Shared examples** live in `spec/support/shared_examples/`; use `it_behaves_like "name"` with keyword args for parameterization. **When reviewing tests or writing model specs, check if a shared example already exists** for the concern being tested — e.g., `"taggable"`, `"a resource that publishes its system events"`, `"a job with account-scoped concurrency limit"`. Using `it_behaves_like` where it fits is better than re-writing equivalent tests inline.
- **Concern helpers**: models using `TrashCanRecoverable` (soft-delete) have `smart_destroy` and `smart_recover`. Test through those, not through direct attribute manipulation. Similarly, `LinkedTo`, `CustomFieldsManager`, and other concerns have dedicated shared examples — use them.
- **`aggregate_failures`** for multiple related assertions where failure of one doesn't invalidate the others
- **Time**: use `travel_to(Time.current)` (Rails built-in) for time-sensitive tests

---

## TDD Workflow

1. **Scaffold first** — create the empty class and stub the method signatures before the first test run. `NameError` / `NoMethodError` are not "red" in a useful sense — they say nothing about behavior.
2. **Write the failing test** — the test should fail with a clear behavioral message: *"expected 3, got nil"* not *"undefined method"*.
3. **Verify the red** — run the test. Confirm the failure message matches what you expect.
4. **Write minimal implementation** — only enough to pass the test. Resist adding behavior the test doesn't demand.
5. **Verify green** — run the test again. It must pass.
6. **Refactor** — improve the code with all tests green. This is when you extract helpers, simplify conditionals, and rename for clarity.
7. **Repeat** — add the next case (edge case, error path, second behavior).

**The test drives the design.** When a test is hard to set up — requiring five `let` blocks and three stubs — that is a design signal, not a testing problem. A class that's painful to test is too coupled. Hard-to-test code and poorly-factored code are the same thing viewed from different angles.

**Find bugs once.** When a bug is found — by QA, in production, by a user — the first step before fixing it is writing a failing test that reproduces it. The test proves the bug exists, the fix makes it pass, and the committed test prevents regression. Every bug found outside your test suite is a gap in your tests. Close it.

**Design by Contract — a lens for writing tests:**
- `context` blocks = *preconditions* (the state and inputs assumed to be true)
- `it` blocks = *postconditions* (what the method guarantees on completion)
- Semantic invariants = things that hold regardless of which path was taken

This framing makes it natural to ask: *what does this method promise?* That promise is what you test.

---

## Test Review Checklist

Run this on every spec before declaring it done:

- [ ] Would this test fail if the method returned `nil`?
- [ ] Does it assert an observable outcome (state, return value, exception, side effect) — not an internal call count?
- [ ] Is the expected value derived independently from the implementation, not copied from it?
- [ ] Is this assertion already owned by the receiver's own spec? (If yes, it's redundant coupling — delete it.)
- [ ] Does it include a "should not" case where one is needed (scopes, filters, validations)?
- [ ] Would it survive renaming an internal private method?
- [ ] Is every `let` and `before` line causally necessary? (Remove anything the test still passes without)
- [ ] Is the failure message informative? Would a reader immediately understand what went wrong?
- [ ] For request specs: are both status code and response body asserted?
- [ ] For scope/query specs: does at least one non-matching record exist?
- [ ] For methods with multiple input/output pairs: is a data table more readable than N identical context blocks?
- [ ] Are there codebase shared examples (`it_behaves_like`) that cover concerns this class includes?
- [ ] For request specs: are params inlined rather than over-extracted to `let` variables the body never uses?
