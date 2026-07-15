# Rails and RSpec patterns

Load this reference when the code under test is Rails/RSpec. These are examples of
the generic principles in `test-principles`, not mandatory templates.

## Setup and data

Choose the least expensive fixture that can prove the behavior:

```ruby
# build: validation and return-value tests; no database write
let(:contact) { build(:contact, account: account, email: "alice@example.com") }

# create: persistence, callbacks, scopes, and association behavior
let(:contact) { create(:contact, account: account, email: "alice@example.com") }

# build_stubbed: only when database behavior is deliberately out of scope
let(:template) { build_stubbed(:workflow_template) }
```

Own every value the assertion depends on. Do not rely on a factory default or
Faker value for an asserted field; use fixed literals. Use `let` for inputs the
example inspects, `let!` only when a record must exist before the action (often an
excluded scope record), and `before` for side effects such as authentication or
feature setup. Avoid `.tap` fixture chains; use explicit creation or nested
attributes so the causal setup is visible.

## Spec level and ownership

| Spec | Assert | Avoid duplicating |
| --- | --- | --- |
| Model/domain | return values, validations with behavior, state transitions, invariants | framework declarations or another object's query semantics |
| Request | status, response shape, authorization, routing, persistence effect | every model validation and private controller state (`assigns`) |
| Service/command | return value, state it changes, jobs/mail/events it emits | internal call chains and collaborator return-value semantics |
| Job | enqueueing in the caller's spec; performed effect in the job spec | testing enqueue and full job behavior as one opaque example |
| System | a critical user journey and visible outcome | every branch already covered below |

For scopes and filters, include a matching record and a deliberately excluded
record. For request specs, assert both the status and the meaningful response body
shape. For multi-account applications, include a cross-account isolation case where
the endpoint promises isolation.

Prefer observable assertions such as:

```ruby
expect { command.perform }
  .to change { workflow.reload.active_step }.to(next_step)
  .and change { workflow.reload.completed_at }.from(nil)

expect { contact.archive! }
  .to have_enqueued_job(ArchiveCleanupJob).with(contact.id)
```

## RSpec doubles

Mock external services, mailers, jobs, and other boundaries when the test does not
need their real implementation. Use real owned models and services. Prefer
verifying doubles; RSpec checks that stubbed methods exist and accept the supplied
arguments when the underlying constant is available.

```ruby
let(:gateway) { instance_double(PaymentGateway, charge: response) }
allow(PaymentGateway).to receive(:new).and_return(gateway)

# After the action, verify the observable boundary interaction if it is yours.
expect(ReceiptMailer).to have_received(:deliver_later)
```

Prefer `have_received` after the action for a side effect over pre-declaring a
long chain of `expect(...).to receive(...)`. Never stub the subject's behavior and
then assert that the stub was called. Avoid message chains, `receive_message_chain`,
`allow_any_instance_of`, and broad `as_null_object` doubles unless a legacy or
framework constraint makes the alternative worse; they hide the real seam.

## Illustrative shapes

```ruby
describe "#archive!" do
  context "when the contact has open tasks" do
    let!(:task) { create(:task, contact: contact) }

    it "leaves the contact active" do
      expect(contact.archive!).to be(false)
      expect(contact.reload).to be_active
    end
  end
end

it "creates the contact and returns its representation" do
  expect {
    post contacts_path,
      params: { contact: { name: "Jane" } },
      as: :json
  }.to change(Contact, :count).by(1)

  expect(response).to have_http_status(:created)
  expect(response.parsed_body["name"]).to eq("Jane")
end
```

When a method maps a fixed set of inputs to specified outputs, a small table is
clearer than repeated contexts. Use explicit examples when setup or assertions
differ materially.
