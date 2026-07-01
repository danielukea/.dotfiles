---
name: write-tests
description: >
  Durable principles for writing and reviewing high-quality, non-tautological
  RSpec tests. Use whenever writing new tests, adding specs to existing code,
  reviewing tests for quality, or doing TDD — or when a user says "write a spec",
  "add tests", "TDD this", "review these tests", "are these tests good?", or
  "check my specs". Also apply proactively when implementing any feature or fix.
  Teaches WHAT makes a test valuable (the discriminator, message-direction,
  semantic invariants, observable outcomes) rather than prescribing a fixed
  workflow. Project-specific conventions (how to run specs, auth setup, shared
  examples, feature flags) belong in that project's rules, not here.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write
---

# Write Tests

Durable principles for RSpec tests that are behavior-driven and non-tautological.
This skill is knowledge, not a procedure — apply the principles in whatever order
the work calls for. Framework- and project-specific conventions (spec runner
command, authentication setup, shared examples, feature-flag helpers) live in the
relevant project's rules, not here.

---

## The Core Test Discriminator

A test is valuable only when it satisfies **both** conditions simultaneously:

1. **It fails when the implementation is wrong** — it would fail against a method
   that returns `nil`, a missing DB constraint, or a broken scope.
2. **It survives a correct refactor** — renaming an internal method, reorganizing
   private helpers, or extracting a collaborator should not break the test.

Tautological tests fail #1 (they pass against broken code). Change-detector tests
fail #2 (they shatter on harmless internal changes). Both are false confidence.

This is the single lens that governs everything below.

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
side effects only: authenticating a user, stubbing a dependency, toggling a flag.

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

- Enable `verify_partial_doubles` in the RSpec config so verifying doubles catch interface drift
- Use `instance_double("ClassName")` with string names for classes that may not be loaded
- Use `have_received` (after the action) rather than `expect(...).to receive` (before) — it reads as verification, not prescription

---

## Factory & Setup Patterns

See `references/factory-patterns.md` for factory/setup patterns (build vs create, `.tap`, nested attributes).

---

## Spec Type Guide

See `references/spec-types.md` for model/request/command/job spec templates.

---

## Tests as a Design Signal

Testing is not a phase that happens after design — the test *is* a design probe.

- **Hard-to-test code is poorly-factored code.** When a test needs five `let` blocks
  and three stubs to set up, that's a coupling signal, not a testing problem. The fix
  is usually in the subject, not the spec.
- **The test can drive the design.** Writing the test first (TDD) is one effective way
  to surface that coupling early — scaffold the class, write a test that fails with a
  *behavioral* message ("expected 3, got nil", not "undefined method"), then implement
  the minimum to pass. Use it when it helps; it's a tool, not a mandate.
- **Find bugs once.** When a bug is found — by QA, in production, by a user — write a
  failing test that reproduces it *before* fixing. The test proves the bug, the fix
  makes it pass, and the committed test prevents regression.
- **Design-by-Contract lens:** `context` blocks are preconditions, `it` blocks are
  postconditions, and semantic invariants hold regardless of path. Asking "what does
  this method promise?" tells you what to assert.

---

## Smells to Watch For

See `references/testing-smells.md` for the diagnostic checklist of test smells.
