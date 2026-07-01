# TDD: `Contact.active` Scope

Following the TDD workflow from the write-tests skill:
1. Scaffold first (empty class + stub method)
2. Write the failing spec
3. Verify red
4. Write minimal implementation
5. Verify green
6. Refactor

---

## Step 1: Scaffold

Before writing the first test, stub the method so that `NameError` / `NoMethodError`
don't pollute the failure output. The scaffold gives us a meaningful red: the scope
returns the wrong records, not a crash.

```ruby
# app/models/contact.rb
class Contact < ApplicationRecord
  belongs_to :account
  # archived_at: datetime, nullable

  scope :active, ->(_account) { none }   # stub — always returns empty
end
```

---

## Step 2: Write the Failing Spec

Key decisions driven by the skill:

- **`require "spec_helper"`** (no `rails_helper` in this repo)
- **`let!` for both included and excluded records** — a scope with only matching
  records cannot catch a query that returns everything (skill rule: always include
  the "should not" side)
- **`contain_exactly`** — verifies exact membership; catches extra records
- **Three exclusion cases** cover both filter axes independently:
  - archived contact in the same account → excluded by `archived_at IS NULL`
  - active contact in a different account → excluded by `account =` filter
  - archived contact in a different account → excluded by both
- Expected values are **literals** from the spec, not derived from implementation

```ruby
# spec/models/contact_spec.rb
require "spec_helper"

RSpec.describe Contact, type: :model do
  describe ".active" do
    let(:account) { create(:account) }
    let(:other_account) { create(:account) }

    # Included record
    let!(:active_contact) { create(:contact, account: account, archived_at: nil) }

    # Excluded: same account, archived
    let!(:archived_contact) { create(:contact, account: account, archived_at: 1.day.ago) }

    # Excluded: different account, not archived
    let!(:other_account_contact) { create(:contact, account: other_account, archived_at: nil) }

    # Excluded: different account AND archived
    let!(:other_archived_contact) { create(:contact, account: other_account, archived_at: 1.day.ago) }

    it "returns only non-archived contacts belonging to the given account" do
      expect(Contact.active(account)).to contain_exactly(active_contact)
    end
  end
end
```

---

## Step 3: Verify Red

Run the spec:

```
bin/wealthbox rspec spec/models/contact_spec.rb
```

With the `none` stub in place, the failure is:

```
expected collection to contain exactly #<Contact id=1 archived_at=nil account_id=1>
but was empty
```

This is the right red — it says "expected a record, got nothing", which is a
behavioral failure. Not a `NameError`.

---

## Step 4: Minimal Implementation

Replace the stub with the real scope. Minimal means: only what the failing test demands.

```ruby
# app/models/contact.rb
class Contact < ApplicationRecord
  belongs_to :account
  # archived_at: datetime, nullable

  scope :active, ->(account) { where(account: account, archived_at: nil) }
end
```

`where(account: account)` uses ActiveRecord's association-aware equality, which
generates `WHERE contacts.account_id = ?`. `where(archived_at: nil)` generates
`WHERE contacts.archived_at IS NULL`. Both conditions must hold simultaneously.

---

## Step 5: Verify Green

Run the spec again:

```
bin/wealthbox rspec spec/models/contact_spec.rb
```

Expected output:

```
Contact
  .active
    returns only non-archived contacts belonging to the given account

1 example, 0 failures
```

---

## Step 6: Refactor

The implementation is already minimal and idiomatic. No refactor needed at this stage.

If the scope were used frequently, we might compose it from named building blocks:

```ruby
scope :not_archived, -> { where(archived_at: nil) }
scope :active,       ->(account) { where(account: account).not_archived }
```

But without a pressing reason (e.g., `not_archived` reused elsewhere), introducing
that decomposition now would be premature — add behavior only when a test demands it.

---

## Final Deliverables

### Spec — `spec/models/contact_spec.rb`

```ruby
require "spec_helper"

RSpec.describe Contact, type: :model do
  describe ".active" do
    let(:account) { create(:account) }
    let(:other_account) { create(:account) }

    let!(:active_contact)       { create(:contact, account: account,       archived_at: nil)       }
    let!(:archived_contact)     { create(:contact, account: account,       archived_at: 1.day.ago) }
    let!(:other_account_contact){ create(:contact, account: other_account, archived_at: nil)       }
    let!(:other_archived_contact){ create(:contact, account: other_account, archived_at: 1.day.ago) }

    it "returns only non-archived contacts belonging to the given account" do
      expect(Contact.active(account)).to contain_exactly(active_contact)
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

---

## Why This Spec Is High-Quality

| Checklist item | Status |
|---|---|
| Would fail if scope returned `nil` or everything? | Yes — `contain_exactly` is strict |
| Asserts an observable outcome (return value)? | Yes |
| Expected value derived from spec, not implementation? | Yes — literals (`nil`, `1.day.ago`) |
| Includes "should not" records? | Yes — 3 excluded records covering both filter axes independently |
| Survives renaming internal methods? | Yes — asserts the public scope's return value only |
| Every `let!` causally necessary? | Yes — remove any one and the test can no longer prove that exclusion |
| Failure message informative? | Yes — `contain_exactly` shows exact diff of present/missing |
