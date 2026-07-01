Here's the spec for `Contacts::ArchiveService`. I'll walk through what to test and what to skip before showing the code.

---

## What to Test

**Happy path — `#call` returns `true` and executes all three side effects:**
The method makes three observable state changes on the success path: the contact is archived, an audit log row is created, and a job is enqueued. Each is independently testable and independently breakable. Test all three, plus the return value.

**Guard path — contact has open tasks:**
The method returns `false` early and must not archive the contact, create an audit log, or enqueue the job. This is the critical boundary condition — the guard must be airtight. Test the return value *and* confirm none of the side effects fired.

**Semantic invariants to verify:**
- `archive!` is not called when there are open tasks (the contact must not end up archived)
- `AuditLog` is not created when there are open tasks (no half-executed audits)
- The job is not enqueued when there are open tasks (no phantom background work)

---

## What to Skip

**Internal call ordering** — the service calls `archive!`, then `AuditLog.create!`, then `ContactArchivedJob.perform_later`. The ordering is an implementation detail; test observable state, not call sequence. Do not assert `received(:archive!).ordered`.

**`AuditLog` internals** — verifying what `AuditLog.create!` does internally (what it persists, what its fields mean) belongs in the `AuditLog` model spec. Here, assert that a row was created and that it captures the right actor/action/subject — which is what this service is responsible for providing.

**`ContactArchivedJob` behavior** — what the job *does* when performed belongs in its own spec. Here, only assert that it was enqueued with the right argument.

**`contact.archive!` behavior** — what `archive!` does on the model (state transitions, callbacks) belongs in the `Contact` or model spec. Here, assert the observable state after the call: `contact.reload.archived?` is true.

**Constructor** — do not test that `initialize` stores `@contact` and `@current_user`. That's testing instance variable assignment, not behavior.

---

## The Spec

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Contacts::ArchiveService do
  subject(:service) { described_class.new(contact, current_user) }

  let(:current_user) { create(:user) }
  let(:contact) { create(:contact) }

  before { Current.user = current_user }

  describe "#call" do
    context "when the contact has no open tasks" do
      it "returns true" do
        expect(service.call).to be(true)
      end

      it "archives the contact" do
        expect { service.call }.to change { contact.reload.archived? }.to(true)
      end

      it "creates an audit log entry for the archive action" do
        expect { service.call }
          .to change { AuditLog.where(user: current_user, action: :archive, subject: contact).count }.by(1)
      end

      it "enqueues ContactArchivedJob with the contact" do
        expect { service.call }.to have_enqueued_job(ContactArchivedJob).with(contact)
      end
    end

    context "when the contact has open tasks" do
      before { create(:task, contact: contact, completed_at: nil) }

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

## Notes on specific choices

**`change { contact.reload.archived? }` not `expect(contact).to have_received(:archive!)`** — testing the persisted state survives a refactor that renames `archive!` or delegates to another method. Testing the method call would shatter on that rename for zero safety gain.

**`change { AuditLog.where(...).count }.by(1)` not `allow(AuditLog).to receive(:create!)`** — the service owns the `AuditLog.create!` call, so use a real DB assertion. Stubbing `AuditLog` and then asserting it received a message is the "stub that tests itself" anti-pattern.

**`not_to change { contact.reload.archived? }` in the open-tasks path** — this confirms the guard actually blocks the state change, not just that it returns early. A broken guard that returns `false` but still calls `archive!` would pass a return-value-only test and fail this one correctly.

**Separate `it` blocks per observable outcome** — archiving, audit log, and job enqueueing are three independent responsibilities. One block failing does not tell you whether the other two are broken. Keeping them separate gives precise failure messages.

**`create(:task, contact: contact, completed_at: nil)`** — explicitly set the field the guard inspects. Don't rely on the factory defaulting to an open task; own what the test asserts on.
