# Review: Bad Contact Spec

## Overall Assessment

Every test in the original spec is tautological or structurally wrong. None of them would
fail against a broken implementation of the behavior they claim to cover. Here is each
problem with its specific fix.

---

## Issue 1: `have_many(:tasks)` — testing the association declaration

```ruby
it { is_expected.to have_many(:tasks) }
```

**Problem:** This is the classic shoulda-matchers tautology for an association with
non-trivial options. The `tasks` association on Contact is defined as
`has_many :tasks, through: :source_links, source: :target, source_type: "Task"` inside
the `PrimaryDocument` concern. The `have_many` matcher does not verify that the `through`,
`source`, and `source_type` options are configured correctly — it only checks that
`has_many :tasks` appears somewhere on the class. A test against a broken `through:`
clause would still pass.

**Fix:** Test the behavior the association enables: create a task linked to the contact
via a source link and assert it appears in `contact.tasks`.

---

## Issue 2: `have_db_column` — testing schema, not behavior

```ruby
it { have_db_column(:email).of_type(:string) }
```

**Problem:** Schema facts belong in migrations and `schema.rb`. This test would pass even
if the `email` column were never read or used anywhere in the model. It also fails the
discriminator: if the column were accidentally dropped, the test would catch it — but so
would every other test that actually exercises email behavior. It provides no unique signal.

Additionally, Contact does not have a single `email` column. Email addresses are stored
in the polymorphic `email_addresses` table. There is no `email` column on `contacts`.
This test would **fail to even load** on the actual schema.

**Fix:** Remove entirely. If email-reading behavior needs coverage, test through
`contact.primary_email` or `contact.email_addresses`.

---

## Issue 3: `respond_to(:archive!)` — testing method presence

```ruby
it { expect(contact).to respond_to(:archive!) }
```

**Problem:** `respond_to` only checks whether the method is defined. It says nothing about
what the method does. If `archive!` were defined as `def archive!; end` (a no-op), this
test would pass. Also: Contact includes `TrashCanRecoverable` which delegates to
`SoftDestroyable`, and the actual soft-delete method is `smart_destroy`, not `archive!`.
There is no `archive!` defined on Contact — this test would pass vacuously through
`method_missing` or fail to find the method at all depending on how respond_to? is wired.

**Fix:** Test the observable outcome of soft-deletion: after `smart_destroy`, the contact
should be soft-deleted (non-nil `deleted_at`) and not appear in the default scope.

---

## Issue 4: Callback existence test — testing wiring not outcome

```ruby
it { expect(contact).to callback(:update_search_index).after(:save) }
```

**Problem:** `callback` matchers verify that a callback is registered, not that it does
anything useful. There is no `update_search_index` callback defined on Contact — the
model uses `OpenSearchIndexable`, and search indexing is triggered via after-commit hooks
internally, not an `after_save :update_search_index`. This test is testing a callback that
does not exist, so it would fail for the wrong reason.

Even if the callback existed, the right test is: does saving the contact trigger the
expected side effect (e.g., a job enqueue)?

**Fix:** Remove. If search indexing needs coverage, test that saving a contact enqueues
the relevant indexing job.

---

## Issue 5: `full_name` — expected value derived from the implementation

```ruby
describe '#full_name' do
  it 'returns the full name' do
    contact = create(:contact, first_name: 'Jane', last_name: 'Smith')
    expected = "#{contact.first_name} #{contact.last_name}"
    expect(contact.full_name).to eq(expected)
  end
end
```

**Problem:** The expected value is computed from `contact.first_name` and
`contact.last_name` — the exact same fields the implementation reads. If `full_name` had
a bug (e.g., returned `"#{last_name} #{first_name}"` or dropped a space), `expected`
would still mirror the broken output and the test would pass.

Also missing:
- **Non-Person contact types**: `full_name` branches on `type`. For `Organization`,
  `Household`, and `Trust`, it returns `name.to_s.strip` — not first/last. The spec only
  covers Person.
- **Whitespace stripping**: `full_name` calls `.strip`. A test with leading/trailing
  whitespace in the names would verify this guard.
- **Nil/blank fields**: What does `full_name` return when `first_name` is nil or blank?

**Fix:** Use literal expected values derived from the specification, not from the object's
own attributes. Cover Person, non-Person (Organization), and edge cases.

---

## Issue 6: Missing middle_name coverage

The task context states that `full_name` concatenates `first_name`, `middle_name`
(optional), and `last_name`. However, the actual implementation for Person is:

```ruby
"#{first_name} #{last_name}"
```

Middle name is **not** included. If the spec were written against the task description
(i.e., asserting `"Jane Marie Smith"`), it would correctly fail — revealing a discrepancy
between spec and implementation. The tautological test above hides this entirely.

---

## Summary of Issues

| Test | Problem | Category |
|------|---------|----------|
| `have_many(:tasks)` | Doesn't verify `through:` options work; would pass with broken join | Tautological — association declaration |
| `have_db_column(:email)` | `email` column doesn't exist on contacts; schema coverage not behavioral | Wrong + schema testing |
| `respond_to(:archive!)` | `archive!` not defined on Contact; respond_to tests existence not behavior | Tautological — method presence |
| `callback(:update_search_index)` | Callback doesn't exist; tests wiring not outcome | Tautological — callback existence |
| `full_name` expected derived from implementation | Both sides of eq mirror each other; can't catch wrong formula | Tautological — implementation echo |
| `full_name` missing non-Person branch | Only covers Person type | Missing coverage |
