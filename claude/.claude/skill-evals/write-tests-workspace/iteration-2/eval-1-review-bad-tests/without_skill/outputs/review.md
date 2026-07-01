# Review: Bad Contact Spec

## Summary

The spec has five distinct problems: tautological tests, schema mismatch, testing framework internals instead of behavior, a missing `archive!` method, and a `#full_name` test that proves nothing.

---

## Problem 1 — `have_many(:tasks)` tests Rails, not your code

```ruby
it { is_expected.to have_many(:tasks) }
```

This calls `shoulda-matchers` to confirm `has_many :tasks` is declared on the model. It passes as long as you typed the macro — it does not verify the association works or that linking a task to a contact actually persists correctly. The association is inherited through `PrimaryDocument` (via `source_links` with `source_type: "Task"`), so the test is even less revealing than it looks. Testing that a method was called on ActiveRecord's DSL is testing Rails, not your application.

**Fix:** Test the behavior the association exists to support — e.g., that a task linked to a contact is returned by `contact.tasks`.

---

## Problem 2 — `have_db_column(:email)` asserts a column that does not exist

```ruby
it { is_expected.to have_db_column(:email).of_type(:string) }
```

The `contacts` table has no `email` column. Emails are stored in a separate `email_addresses` table associated through `has_many :email_addresses`. This test would fail outright if run, and even if it passed it would only prove your migration ran — something already guaranteed by the schema file and every other test that loads the DB.

**Fix:** Remove this test entirely. If you want to verify email retrieval works, test the behavior (e.g., that `contact.email_addresses.first.address` returns expected data).

---

## Problem 3 — `respond_to(:archive!)` tests a method that does not exist on Contact

```ruby
it { expect(contact).to respond_to(:archive!) }
```

`Contact` includes `TrashCanRecoverable` → `SoftDestroyable` → `acts_as_paranoid`. The soft-delete interface exposes `destroy`, `deleted?`, `recover!`, and `smart_destroy` — not `archive!`. The method `archive!` is defined on `Team`, not `Contact`. This test would fail. Even if you renamed the method correctly, `respond_to` only proves the method name exists — it says nothing about what it does.

**Fix:** Test the actual soft-delete behavior: that calling `smart_destroy` sets `deleted_at` and that `Contact.only_deleted` surfaces the record.

---

## Problem 4 — `callback(:update_search_index).after(:save)` tests implementation wiring, not behavior

```ruby
it { expect(contact).to callback(:update_search_index).after(:save) }
```

This asserts that the callback is registered, not that the search index is actually updated when a contact is saved. Callback registration tests are brittle: they break on refactors (e.g., moving the callback to a concern or an `after_commit`) even when behavior is unchanged. The important contract is that saving a contact causes its search index to reflect the new data.

**Fix:** Test that saving a contact with changed attributes causes `OpenSearchIndexable` behavior to fire — or, if you must test search indexing specifically, stub/spy on the indexer and assert it was called with the right arguments.

---

## Problem 5 — `#full_name` test is tautological

```ruby
describe '#full_name' do
  it 'returns the full name' do
    contact = create(:contact, first_name: 'Jane', last_name: 'Smith')
    expected = "#{contact.first_name} #{contact.last_name}"
    expect(contact.full_name).to eq(expected)
  end
end
```

The `expected` value is constructed by reading back `contact.first_name` and `contact.last_name` from the already-persisted object. This is circular: if the implementation had a bug that mangled names on save (e.g., through `StringCleaner`), both the expected string and the actual value would be wrong in the same way, and the test would still pass.

Additionally, the test only covers the `Person` type code path. Looking at the implementation:

```ruby
def full_name
  ((type == "Person") ? "#{first_name} #{last_name}" : name).to_s.strip
end
```

There are at least three behaviors to cover: Person (concatenates first + last), non-Person (uses `name`), and the `.strip` behavior for whitespace.

**Fix:** Use literal string expectations with `build` (not `create` — no DB needed for a pure method). Cover both the Person and Organization branches, plus edge cases like nil/blank names.

---

## Summary of Issues

| Test | Problem | Category |
|---|---|---|
| `have_many(:tasks)` | Tests Rails DSL, not behavior | Testing framework, not app |
| `have_db_column(:email)` | Column does not exist; tests schema not behavior | Wrong/missing assertion |
| `respond_to(:archive!)` | Method does not exist on Contact | Tests wrong interface |
| `callback(:update_search_index)` | Tests wiring not outcome | Implementation detail |
| `#full_name` tautology | Expected value derived from subject | Self-referential assertion |
