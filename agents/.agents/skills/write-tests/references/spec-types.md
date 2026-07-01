# Spec type guide

These show how the `write-tests` principles land for each spec type. They are illustrative
shapes, not mandatory templates.

### Model specs

```ruby
# Structural coverage — one-liners for plain validations/associations
it { is_expected.to validate_presence_of(:name) }
it { is_expected.to belong_to(:account) }

# Behavioral coverage — needed for conditional validations, options, messages
describe "#archive!" do
  context "when the contact has open tasks" do
    let!(:task) { create(:task, contact: contact) }

    it "does not archive and returns false" do
      expect(contact.archive!).to be(false)
      expect(contact).not_to be_archived
    end
  end
end
```

Never mock the model in its own spec — use real objects and real DB interactions.

### Request specs

```ruby
before { authenticate(user) }  # however this app logs a user in for requests

it "creates the record and returns 201" do
  expect {
    post contacts_path, params: { contact: { name: "Jane" } }, as: :json
  }.to change { Contact.count }.by(1)

  expect(response).to have_http_status(:created)
  expect(response.parsed_body["name"]).to eq("Jane")
end

it "returns 422 with validation errors" do
  post contacts_path, params: { contact: { name: "" } }, as: :json
  expect(response).to have_http_status(:unprocessable_entity)
  expect(response.parsed_body["errors"]["name"]).to be_present
end
```

Always assert both the **status code** and the **response body shape**. Don't use
`assigns(:variable)` — it tests internal controller state, not observable HTTP output.

**Inline request params — don't over-extract to `let`.**
A `let` is only justified if the test body needs to reference the variable. Params used
only in the request call belong inline:

```ruby
# Bad — params extracted to lets that the assertions never reference
let(:valid_params) { { contact: { first_name: "Jane", last_name: "Smith", type: "Person" } } }
it "creates the contact" do
  expect { post contacts_path, params: valid_params, as: :json }.to change { Contact.count }.by(1)
end

# Good — inline params; only the response and DB state are asserted
it "creates the contact" do
  expect {
    post contacts_path, params: { contact: { first_name: "Jane", last_name: "Smith", type: "Person" } }, as: :json
  }.to change { Contact.count }.by(1)
  expect(response).to have_http_status(:ok)
end
```

Test the **behavior that belongs to the request layer** — auth, routing, response shape,
and persistence side effects. Don't exhaustively re-test every model validation in request
specs; those belong in model specs.

Cross-account isolation is a required test for any endpoint that scopes by account:
```ruby
context "when the resource belongs to a different account" do
  let(:other_contact) { create(:contact, account: create(:account)) }

  it "returns 404" do
    get contact_path(other_contact)
    expect(response).to have_http_status(:not_found)
  end
end
```

### Command / service specs

```ruby
subject(:command) { described_class.new(workflow, step) }

describe "#perform" do
  it "transitions the workflow to the next step" do
    expect { command.perform }
      .to change { workflow.reload.active_step }.to(next_step)
  end

  context "when the step has no successor" do
    it "marks the workflow as complete" do
      expect { command.perform }
        .to change { workflow.reload.completed? }.to(true)
    end
  end
end
```

Test return value, state changes, and enqueued side effects — not internal call chains.

### Job specs

Separate the "does it enqueue?" test from the "does it do the right thing?" test:

```ruby
it "enqueues the cleanup job after archiving" do
  expect { contact.archive! }.to have_enqueued_job(ArchiveCleanupJob).with(contact.id)
end

it "deletes the exports when performed" do
  create_list(:export, 3, contact: contact)
  expect { ArchiveCleanupJob.perform_now(contact.id) }
    .to change { Export.where(contact: contact).count }.to(0)
end
```

