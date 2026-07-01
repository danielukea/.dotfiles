# frozen_string_literal: true

require "spec_helper"

describe "ContactsController#create", type: :request do
  let(:user) { create(:user_owner) }

  before do
    Current.user = user
    login_with user
  end

  describe "POST /contacts" do
    context "when the request is valid" do
      it "creates the contact and returns it in the response" do
        expect {
          post contacts_path,
            params: { contact: { type: "Person", first_name: "Jane", last_name: "Smith" } },
            as: :json
        }.to change { Contact.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["first_name"]).to eq("Jane")
        expect(response.parsed_body["last_name"]).to eq("Smith")
      end
    end

    context "when the name fields are missing" do
      it "does not create a contact and returns 422 with validation errors" do
        expect {
          post contacts_path,
            params: { contact: { type: "Person", first_name: "", last_name: "" } },
            as: :json
        }.not_to change { Contact.count }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["base"]).to be_present
      end
    end

    context "when contact_source_id belongs to a different account" do
      it "does not create the contact and returns 422" do
        other_account = create(:account)
        other_contact_source = create(:contact_source, account: other_account)

        expect {
          post contacts_path,
            params: {
              contact: {
                type: "Person",
                first_name: "Jane",
                last_name: "Smith",
                contact_source_id: other_contact_source.id
              }
            },
            as: :json
        }.not_to change { Contact.count }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
