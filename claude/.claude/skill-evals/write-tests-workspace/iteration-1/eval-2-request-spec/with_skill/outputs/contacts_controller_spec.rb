# frozen_string_literal: true

require "spec_helper"

describe "Contacts Controller", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user_owner, account: account) }

  before do
    Current.user = user
    login_with(user)
  end

  describe "POST /contacts" do
    context "when params are valid" do
      it "creates the contact and returns 200 with the contact in the response" do
        expect {
          post contacts_path, params: { contact: { first_name: "Jane", last_name: "Doe", type: "Person" } }, as: :json
        }.to change { Contact.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["first_name"]).to eq("Jane")
        expect(response.parsed_body["last_name"]).to eq("Doe")
      end
    end

    context "when name is missing" do
      it "returns 422 with validation errors" do
        expect {
          post contacts_path, params: { contact: { type: "Person" } }, as: :json
        }.not_to change { Contact.count }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["base"]).to include("First name or Last name must be provided")
      end
    end

    context "when contact_source_id belongs to a different account" do
      let(:other_account) { create(:account) }
      let(:other_contact_source) { create(:contact_source, account: other_account) }

      it "returns 422 with a same-account validation error" do
        expect {
          post contacts_path, params: {
            contact: { first_name: "Jane", last_name: "Doe", type: "Person", contact_source_id: other_contact_source.id }
          }, as: :json
        }.not_to change { Contact.count }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["contact_source"]).to be_present
      end
    end
  end
end
