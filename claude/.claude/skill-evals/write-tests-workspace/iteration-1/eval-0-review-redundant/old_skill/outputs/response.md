# Spec Review: Tasks::AssignCommand

Here's a breakdown of every assertion in this spec, with recommendations on which to remove or change and why.

---

## Remove: "responds to full_name"

```ruby
it "responds to full_name" do
  expect(user).to respond_to(:full_name)
end
```

**Remove this entirely.** This is a classic tautological test — it tests method *presence*, not method *behavior*. It will pass even if `full_name` returns `nil`, an empty string, or raises an error internally. It tells you nothing about what `full_name` does or whether `AssignCommand` uses it correctly. The skill's guidance is explicit: *"Test what the method does, not that it exists."*

---

## Remove or merge: "sets the assignee name"

```ruby
it "sets the assignee name" do
  command.perform
  expect(task.assignee.full_name).to eq(user.full_name)
end
```

**Remove or restructure this.** The expected value is derived directly from the same object under test (`user.full_name`). If `full_name` has a bug that produces the wrong string, both sides of the assertion produce the same wrong string, and the test still passes. This is the *"expected value derived from the implementation"* anti-pattern from the skill guide.

If you need to assert something meaningful about the name, use a literal:

```ruby
let(:user) { create(:user, first_name: "Jane", last_name: "Smith") }

it "exposes the assignee's full name" do
  command.perform
  expect(task.reload.assignee.full_name).to eq("Jane Smith")
end
```

However, if the point of this test is just to confirm the right user was assigned, the "updates the assignee" test already covers that with a stronger assertion (`eq(user)`). A separate name check is redundant unless there's a specific formatting concern you need to pin down.

---

## Redundant with "updates the assignee": "increments the assignee count"

```ruby
it "increments the assignee count" do
  command.perform
  expect(task.assignees.count).to eq(1)
end
```

**Likely redundant — consider removing or collapsing.** The "updates the assignee" test already verifies that `task.reload.assignee` is `user`. If `assignees` is the collection backing that association, this test is confirming the same fact in a less precise way (count of 1 vs. the specific user). It cannot catch a bug where the wrong user was assigned but *some* user was assigned.

If `task` can have multiple assignees and you want to confirm exactly one was added (not duplicated), this test has value — but then the description should say *"adds exactly one assignee record"* and you should assert `change { task.assignees.count }.by(1)`, not a hardcoded `eq(1)` that depends on the factory leaving `task.assignees` empty.

Use the `change {}` form instead:

```ruby
it "adds the user as an assignee" do
  expect { command.perform }
    .to change { task.assignees.count }.by(1)
end
```

---

## Keep: "updates the assignee"

```ruby
it "updates the assignee" do
  command.perform
  expect(task.reload.assignee).to eq(user)
end
```

**Keep this.** It asserts a concrete, observable persisted state change with a specific expected value. It would fail if `assignee` were nil, were the wrong user, or were never persisted. This is the highest-priority assertion form.

One small improvement: prefer the `change {}` idiom to make the before/after explicit:

```ruby
it "assigns the user to the task" do
  expect { command.perform }
    .to change { task.reload.assignee }.from(nil).to(user)
end
```

---

## Keep: "enqueues the notification job"

```ruby
it "enqueues the notification job" do
  expect { command.perform }.to have_enqueued_job(NotificationJob).with(task)
end
```

**Keep this.** It tests a real side effect (job enqueue) against a specific argument. It would fail if the job is never enqueued, enqueued with different arguments, or the job class is renamed without updating the command. This is the correct pattern for verifying side effects.

---

## Summary

| Assertion | Verdict | Reason |
|---|---|---|
| "updates the assignee" | Keep (minor improvement possible) | Strong behavioral assertion on persisted state |
| "enqueues the notification job" | Keep | Verifies a real, observable side effect |
| "increments the assignee count" | Restructure or remove | Weak form of "updates assignee"; use `change { }.by(1)` if there's distinct value |
| "sets the assignee name" | Remove or fix | Expected value derived from the same object — tautological |
| "responds to full_name" | Remove | Tests method existence, not behavior — provides zero coverage |
