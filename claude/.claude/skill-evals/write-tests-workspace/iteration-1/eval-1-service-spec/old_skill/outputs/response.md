Here is the spec for `Contacts::ArchiveService`.

---

## What to test

**Test:**
1. Return value — `call` returns `true` on success, `false` when blocked by open tasks
2. State change — the contact is archived after a successful call
3. Side effects — `AuditLog` record is created with the right attributes; `ContactArchivedJob` is enqueued
4. Guard clause — when the contact has open tasks, none of the above side effects happen

**Skip:**
- The implementation of `open_tasks` (that belongs in a Contact model spec)
- The implementation of `archive!` itself (that belongs in a Contact model spec)
- What `ContactArchivedJob` does when it runs (that belongs in a job spec)
- Database schema / column presence

---

## The spec

```ruby
# frozen_string_literal: true

require "spec_helper"

describe Contacts::ArchiveService do
  subject(:service) { described_class.new(contact, current_user) }

  let(:current_user) { create(:user) }
  let(:contact) { create(:contact, account: current_user.account) }

  before { Current.user = current_user }

  describe "#call" do
    context "when the contact has no open tasks" do
      it "returns true" do
        expect(service.call).to be(true)
      end

      it "archives the contact" do
        expect { service.call }
          .to change { contact.reload.archived? }.from(false).to(true)
      end

      it "creates an audit log entry for the archive action" do
        expect { service.call }
          .to change { AuditLog.count }.by(1)

        log = AuditLog.last
        aggregate_failures do
          expect(log.user).to eq(current_user)
          expect(log.action.to_sym).to eq(:archive)
          expect(log.subject).to eq(contact)
        end
      end

      it "enqueues ContactArchivedJob for the contact" do
        expect { service.call }
          .to have_enqueued_job(ContactArchivedJob).with(contact)
      end
    end

    context "when the contact has open tasks" do
      before { create(:task, link_to: contact) }

      it "returns false" do
        expect(service.call).to be(false)
      end

      it "does not archive the contact" do
        expect { service.call }.not_to change { contact.reload.archived? }
      end

      it "does not create an audit log entry" do
        expect { service.call }.not_to change { AuditLog.count }
      end

      it "does not enqueue ContactArchivedJob" do
        expect { service.call }.not_to have_enqueued_job(ContactArchivedJob)
      end
    end
  end
end
```

---

## Notes on decisions made

**Why separate `it` blocks for each side effect rather than one big example?**
The guard-clause branch has four observable consequences (return value, no state change, no audit log, no job). Each is a distinct postcondition — collapsing them hides which assertion failed and whether the failure is related to the guard or a specific effect.

**Why `have_enqueued_job` instead of `expect(ContactArchivedJob).to receive(:perform_later)`?**
`have_enqueued_job` asserts the enqueue as an outcome of the action rather than prescribing a call before the action runs. It also survives extraction of the enqueue into a private method.

**Why `aggregate_failures` on the audit log attributes?**
All three attributes (`user`, `action`, `subject`) are part of the same record's correctness. If one is wrong we want to see all failures, not just the first.

**Why link a task using `link_to: contact` (the factory transient) rather than `contact.tasks.create!` or a stub on `open_tasks`?**
The factory transient is the canonical factory way to link tasks to contacts in this codebase. Using a real DB record means the guard clause is tested through the actual `open_tasks` query — which is the behavior we care about. If someone changes the `open_tasks` scope so it stops seeing this task, the test will correctly fail.

**What's skipped and why:**
- The internals of `open_tasks`, `archive!` — those are the contact model's contract, not this service's.
- `ContactArchivedJob` behavior when performed — that's the job spec's job.
- AuditLog schema/column presence — irrelevant to service behavior.
- No request spec coverage here — the service is called from somewhere in the controller layer, but testing that round-trip belongs in a request spec for the archive endpoint, not here.
