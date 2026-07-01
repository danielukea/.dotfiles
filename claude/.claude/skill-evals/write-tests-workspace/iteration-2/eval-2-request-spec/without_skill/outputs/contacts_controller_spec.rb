# frozen_string_literal: true

require "spec_helper"

describe "Contacts Controller", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user_owner, account: account) }

  before do
    login_with user
    Current.user = user
  end

  describe "POST /contacts" do
    context "successful creation" do
      let(:params) do
        {
          contact: {
            type: "Person",
            first_name: "Jane",
            last_name: "Smith"
          },
          format: "json"
        }
      end

      it "returns 200 with the contact in the response" do
        expect {
          post contacts_path, params: params
        }.to change { Contact.count }.by(1)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body["first_name"]).to eq("Jane")
        expect(body["last_name"]).to eq("Smith")
      end
    end

    context "missing required name field" do
      let(:params) do
        {
          contact: {
            type: "Person",
            first_name: "",
            last_name: ""
          },
          format: "json"
        }
      end

      it "returns 422 with validation errors" do
        expect {
          post contacts_path, params: params
        }.not_to change { Contact.count }

        expect(response).to have_http_status(:unprocessable_entity)
        body = response.parsed_body
        expect(body["base"]).to be_present
      end
    end

    context "contact_source_id from a different account" do
      let(:other_account) { create(:account) }
      let(:other_contact_source) { create(:contact_source, account: other_account) }
      let(:params) do
        {
          contact: {
            type: "Person",
            first_name: "Jane",
            last_name: "Smith",
            contact_source_id: other_contact_source.id
          },
          format: "json"
        }
      end

      it "returns 422 with validation errors" do
        expect {
          post contacts_path, params: params
        }.not_to change { Contact.count }

        expect(response).to have_http_status(:unprocessable_entity)
        body = response.parsed_body
        expect(body["contact_source"]).to be_present
      end
    end
  end
end
