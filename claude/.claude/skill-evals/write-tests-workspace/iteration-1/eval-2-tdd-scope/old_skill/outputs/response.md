# TDD: `Contact.active` scope

Following the TDD workflow from the skill:
1. Scaffold the empty scope stub
2. Write the failing spec
3. Verify red (behavioral failure, not NameError)
4. Write minimal implementation
5. Verify green
6. Refactor if needed

---

## Step 1 — Scaffold (stub the scope so tests fail behaviorally, not with NameError)

```ruby
# app/models/contact.rb
class Contact < ApplicationRecord
  belongs_to :account
  # archived_at: datetime, nullable

  scope :active, ->(_account) { none }
end
```

The stub returns `none` so the first test run produces a clear behavioral failure
(*"expected to contain exactly [...], got []"*) rather than an unhelpful `NoMethodError`.

---

## Step 2 — Spec

```ruby
# spec/models/contact_spec.rb
require "spec_helper"

describe Contact do
  describe ".active" do
    let(:account) { create(:account) }
    let(:other_account) { create(:account) }

    let!(:active_contact)   { create(:contact, account: account, archived_at: nil) }
    let!(:archived_contact) { create(:contact, account: account, archived_at: 1.day.ago) }
    let!(:other_account_contact) { create(:contact, account: other_account, archived_at: nil) }

    it "returns contacts where archived_at is nil for the given account" do
      expect(Contact.active(account)).to contain_exactly(active_contact)
    end

    it "excludes archived contacts" do
      expect(Contact.active(account)).not_to include(archived_contact)
    end

    it "excludes contacts belonging to a different account" do
      expect(Contact.active(account)).not_to include(other_account_contact)
    end
  end
end
```

### Why this spec is non-tautological

- **Inclusion proven by exclusion**: `archived_contact` and `other_account_contact` both exist
  in the DB. If the scope returned all contacts, `contain_exactly(active_contact)` would
  fail — proving the filter is actually applied.
- **`contain_exactly`** asserts exact membership (no extras, no missing). A scope that
  returns `Contact.all` would fail immediately.
- **Two separate exclusion conditions** are each tested — `archived_at IS NOT NULL` and
  `account_id != account.id` — so neither filter can silently disappear.
- **Expected value (`active_contact`) is derived from the spec**, not from the
  implementation. We know exactly which record should appear because we created it with
  the right attributes.

### Applying the skill's scope checklist

- [x] At least one non-matching record exists (`archived_contact`, `other_account_contact`)
- [x] Uses `let!` so excluded records are persisted before the example runs
- [x] Asserts the "should not" side explicitly (two `not_to include` examples)
- [x] `contain_exactly` catches a query that returns everything
- [x] No tautological patterns (no `respond_to`, no schema checks)

---

## Step 3 — Verify Red (expected failure messages)

Running `bin/wealthbox rspec spec/models/contact_spec.rb` against the scaffold:

```
1) Contact.active returns contacts where archived_at is nil for the given account
   Failure/Error: expect(Contact.active(account)).to contain_exactly(active_contact)
     expected collection to contain exactly #<Contact id=1 ...>
     but it was empty
```

This is a behavioral failure — it tells us exactly what's wrong. Not a `NameError`.

---

## Step 4 — Minimal Implementation

```ruby
# app/models/contact.rb
class Contact < ApplicationRecord
  belongs_to :account
  # archived_at: datetime, nullable

  scope :active, ->(account) { where(account: account, archived_at: nil) }
end
```

This is the simplest implementation that satisfies all three tests:
- `where(account: account)` scopes to the given account
- `where(archived_at: nil)` excludes archived contacts
- Both conditions are AND-ed together in a single `WHERE` clause

---

## Step 5 — Verify Green

Running `bin/wealthbox rspec spec/models/contact_spec.rb`:

```
Contact
  .active
    returns contacts where archived_at is nil for the given account
    excludes archived contacts
    excludes contacts belonging to a different account

3 examples, 0 failures
```

---

## Step 6 — Refactor (none needed)

The implementation is already minimal and readable. `where(account: account, archived_at: nil)`
reads exactly like the business rule it encodes. No refactoring required.

---

## Final Files

### Spec — `spec/models/contact_spec.rb`

```ruby
require "spec_helper"

describe Contact do
  describe ".active" do
    let(:account) { create(:account) }
    let(:other_account) { create(:account) }

    let!(:active_contact)        { create(:contact, account: account, archived_at: nil) }
    let!(:archived_contact)      { create(:contact, account: account, archived_at: 1.day.ago) }
    let!(:other_account_contact) { create(:contact, account: other_account, archived_at: nil) }

    it "returns contacts where archived_at is nil for the given account" do
      expect(Contact.active(account)).to contain_exactly(active_contact)
    end

    it "excludes archived contacts" do
      expect(Contact.active(account)).not_to include(archived_contact)
    end

    it "excludes contacts belonging to a different account" do
      expect(Contact.active(account)).not_to include(other_account_contact)
    end
  end
end
```

### Implementation — `app/models/contact.rb`

```ruby
class Contact < ApplicationRecord
  belongs_to :account
  # archived_at: datetime, nullable

  scope :active, ->(account) { where(account: account, archived_at: nil) }
end
```
