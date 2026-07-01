# Test Review: Contact Spec

## Summary

The submitted spec contains five distinct problems: four tautological anti-patterns
and one test that derives its expected value from the implementation rather than from
independent specification. None of the tests would catch a broken implementation that
simply returns the right type of object but with wrong data.

---

## Issue 1 — Testing association declarations (tautological)

```ruby
it { is_expected.to have_many(:tasks) }
```

**Why it's wrong:** This only checks that `has_many :tasks` appears in the source
file (or that shoulda-matchers can reflect on it). It does not verify that the
association actually works — that a Task linked to the contact appears in
`contact.tasks`. A developer could break the `through:` options or the `source_type`
and this test would still pass.

**What to do instead:** Test that a linked task appears in the collection. The `tasks`
association on Contact is a `through: :source_links` join with `source_type: "Task"`,
so the real risk is the join configuration, not the declaration. Test it behaviorally.

---

## Issue 2 — Testing database schema (tautological)

```ruby
it { have_db_column(:email).of_type(:string) }
```

**Why it's wrong:** Schema facts belong in the migration and `schema.rb`. A spec
checking for a column's existence and type will pass even if the column is never
read, never validated, and never visible in the application. It provides zero signal
about whether the email column is actually used correctly.

**What to do instead:** Remove this test entirely. If there is behavior that depends
on the email column — for example, the contact can be looked up by email — test that
behavior.

---

## Issue 3 — Testing method presence (tautological)

```ruby
it { expect(contact).to respond_to(:archive!) }
```

**Why it's wrong:** This passes as long as `archive!` is defined anywhere — even if
its body is `nil`. It gives no information about what `archive!` does.

**What to do instead:** Test what `archive!` actually does. Looking at the codebase,
Contact includes `TrashCanRecoverable` which includes `SoftDestroyable` (acts_as_paranoid).
The observable effect of destroying a contact is that its `deleted_at` is set. Test that.

---

## Issue 4 — Testing callbacks (tautological)

```ruby
it { expect(contact).to callback(:update_search_index).after(:save) }
```

**Why it's wrong:** This verifies that the callback is registered, not that it does
anything useful. If `update_search_index` is renamed, extracted, or moved to a job,
this test breaks even if the search index is still correctly updated.

**What to do also note:** `update_search_index` does not exist in the Contact model
in this codebase — there is no such callback. This test would fail at the registration
level immediately.

**What to do instead:** Test the observable result: is the contact findable in the
search index after saving? Or if this is a job enqueue, does the job get enqueued?

---

## Issue 5 — Expected value derived from the implementation (tautological)

```ruby
describe '#full_name' do
  it 'returns the full name' do
    contact = create(:contact, first_name: 'Jane', last_name: 'Smith')
    expected = "#{contact.first_name} #{contact.last_name}"
    expect(contact.full_name).to eq(expected)
  end
end
```

**Why it's wrong:** The `expected` value is derived by reading back the attributes
from the already-created contact and assembling them with the same interpolation
pattern the implementation uses. If the implementation returned
`"#{contact.last_name} #{contact.first_name}"` (reversed), both sides of the
assertion would still agree — the test cannot tell.

**Also:** The task description says `full_name` concatenates `first_name`,
`middle_name` (optional), and `last_name`. But the actual implementation is:
```ruby
def full_name
  ((type == "Person") ? "#{first_name} #{last_name}" : name).to_s.strip
end
```
Middle name is **not** included. The test also does not cover: (a) the Organization
path (returns `name` field), (b) extra whitespace when names have leading/trailing
spaces, (c) what happens when first_name or last_name is nil.

**What to do instead:** Use literal expected values that are independent of the
implementation, and cover the meaningful branches.

---

## Additional Structural Issues

- `let(:contact) { create(:contact) }` at the top uses `create` (a DB write) for
  every example, including the `full_name` test that later shadows it with a new
  `create`. The outer `let` is never used and adds unnecessary DB cost.
- The tests do not set `Current.user`, which is required for Contact persistence in
  this codebase. Tests that call `create(:contact)` without a `Current.user` set will
  fail or produce unexpected behavior.
- The spec file does not use `# frozen_string_literal: true`, inconsistent with the
  rest of the codebase.
