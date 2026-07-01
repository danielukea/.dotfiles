# Spec Review: `Tasks::AssignCommand`

Here's an analysis of each assertion, flagged against the core test principles.

---

## Remove: `"responds to full_name"`

```ruby
it "responds to full_name" do
  expect(user).to respond_to(:full_name)
end
```

**Remove this entirely.** This is a textbook tautological test — it tests method *presence*, not method *behavior*. The skill explicitly flags `respond_to` as a pattern that provides no coverage. The method could exist and return `nil`, `""`, or raise — and this test would still pass. If you need to verify that `full_name` works correctly, test what it returns.

---

## Remove: `"increments the assignee count"`

```ruby
it "increments the assignee count" do
  command.perform
  expect(task.assignees.count).to eq(1)
end
```

**Remove this.** This is a cross-ownership violation. The `assignees.count` behavior belongs to the `Task` model spec — it's an outgoing query result that `Tasks::AssignCommand` doesn't own. Per the Message-Direction Heuristic: the receiver's spec owns the assertion. If `Task#assignees` is broken, the `Task` model spec should catch it — not the command spec.

Adding this assertion here creates coupling with no safety gain. A change to how `Task` counts assignees would break two specs for one behavioral issue.

---

## Change: `"sets the assignee name"` — currently redundant with `"updates the assignee"`

```ruby
it "sets the assignee name" do
  command.perform
  expect(task.assignee.full_name).to eq(user.full_name)
end
```

**Remove or consolidate.** This test asserts `task.assignee.full_name == user.full_name`. But `"updates the assignee"` already asserts `task.reload.assignee == user`. If the assignee is correctly set to `user`, then `task.assignee.full_name` is `user.full_name` by identity — you don't need a separate test to prove it. This test adds no failure scenario the existing test doesn't already catch.

There's also a secondary issue: the expected value is derived from the object under test rather than a fixed literal. `user.full_name` as the expected value means if `full_name` is broken, both sides are wrong and the test passes anyway.

If you want to cover `full_name` formatting specifically, that belongs in a `User` model spec with a literal expected value:

```ruby
# In user_spec.rb
it "formats the full name" do
  user = build(:user, first_name: "Jane", last_name: "Smith")
  expect(user.full_name).to eq("Jane Smith")
end
```

---

## Change: `"updates the assignee"` — use `change { }` instead of reload-after-the-fact

```ruby
it "updates the assignee" do
  command.perform
  expect(task.reload.assignee).to eq(user)
end
```

**Keep the intent, improve the form.** This is the most important assertion in the spec and correctly asserts owned, observable state. However, the `change { }` pattern is cleaner and makes the before/after explicit:

```ruby
it "updates the assignee" do
  expect { command.perform }
    .to change { task.reload.assignee }.from(nil).to(user)
end
```

This makes the starting state explicit and forces the reader to see what changed, not just what the final value is.

---

## Keep (with minor note): `"enqueues the notification job"`

```ruby
it "enqueues the notification job" do
  expect { command.perform }.to have_enqueued_job(NotificationJob).with(task)
end
```

**Keep this.** Enqueuing a job is an outgoing command side effect — exactly what the command spec should assert. The `expect { }.to have_enqueued_job` form is correct. No changes needed here.

---

## Summary Table

| Assertion | Verdict | Reason |
|---|---|---|
| `"updates the assignee"` | Keep, improve | Correct ownership; use `change { }` form |
| `"enqueues the notification job"` | Keep as-is | Correct outgoing command assertion |
| `"increments the assignee count"` | Remove | Cross-ownership; belongs in Task model spec |
| `"sets the assignee name"` | Remove | Redundant with assignee identity check; expected value derived from subject |
| `"responds to full_name"` | Remove | Tests method presence, not behavior — tautological |

---

## What the Spec Should Look Like After Cleanup

```ruby
RSpec.describe Tasks::AssignCommand do
  let(:task) { create(:task) }
  let(:user) { create(:user) }
  subject(:command) { described_class.new(task, user) }

  describe "#perform" do
    it "updates the assignee" do
      expect { command.perform }
        .to change { task.reload.assignee }.from(nil).to(user)
    end

    it "enqueues the notification job" do
      expect { command.perform }.to have_enqueued_job(NotificationJob).with(task)
    end
  end
end
```

Three assertions became two. The surviving tests catch real behavioral regressions and survive any internal refactor of the command. The removed ones either tested the wrong object, duplicated coverage, or proved nothing.
