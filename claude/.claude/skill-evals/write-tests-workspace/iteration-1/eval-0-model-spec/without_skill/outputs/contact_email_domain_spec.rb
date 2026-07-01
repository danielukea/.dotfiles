# frozen_string_literal: true

require "spec_helper"

describe Contact do
  let(:user) { create(:user_owner) }

  before do
    Current.user = user
  end

  describe "#email_domain" do
    context "when the contact has a primary email with a domain" do
      let(:contact) do
        create(:contact, email_addresses_attributes: [{ address: "alice@acme.com", kind: "work", principal: true }])
      end

      it "returns the domain portion of the email" do
        expect(contact.email_domain).to eq("acme.com")
      end
    end

    context "when the email has a subdomain" do
      let(:contact) do
        create(:contact, email_addresses_attributes: [{ address: "bob@mail.example.org", kind: "work", principal: true }])
      end

      it "returns the full domain including subdomains" do
        expect(contact.email_domain).to eq("mail.example.org")
      end
    end

    context "when the contact has no email addresses" do
      let(:contact) { create(:contact) }

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the primary email is blank" do
      let(:contact) do
        create(:contact, email_addresses_attributes: [{ address: "", kind: "work", principal: true }])
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the email has no @ sign" do
      let(:contact) do
        create(:contact, email_addresses_attributes: [{ address: "notanemail", kind: "work", principal: true }])
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the email ends with @" do
      let(:contact) do
        create(:contact, email_addresses_attributes: [{ address: "user@", kind: "work", principal: true }])
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end
  end
end
