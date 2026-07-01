# frozen_string_literal: true

require "spec_helper"

describe "Contacts Controller", type: :request do
  let(:user) { create(:user_owner) }

  before do
    Current.user = user
    login_with(user)
  end

  describe "POST /contacts" do
    let(:valid_params) do
      {
        contact: {
          type: "Person",
          first_name: "Jane",
          last_name: "Doe"
        },
        format: "json"
      }
    end

    context "successful creation" do
      it "returns 200 with the contact in the response" do
        expect {
          post contacts_path, params: valid_params
        }.to change { Contact.count }.by(1)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("first_name" => "Jane", "last_name" => "Doe")
      end
    end

    context "missing required name field" do
      let(:missing_name_params) do
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
          post contacts_path, params: missing_name_params
        }.not_to change { Contact.count }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body).to include("base" => include("First name or Last name must be provided"))
      end
    end

    context "contact_source_id from a different account" do
      let(:other_account) { create(:account) }
      let(:foreign_contact_source) { create(:contact_source, account: other_account) }

      it "returns 422 with a validation error" do
        expect {
          post contacts_path, params: valid_params.deep_merge(
            contact: { contact_source_id: foreign_contact_source.id }
          )
        }.not_to change { Contact.count }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body.to_s).to include("does not exist in this Workspace")
      end
    end
  end
end
