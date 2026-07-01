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
        create(:contact, email_addresses_attributes: [{ address: "alice@acme.com", principal: true, kind: "work" }])
      end

      it "returns the domain part of the email" do
        expect(contact.email_domain).to eq("acme.com")
      end
    end

    context "when the email has a subdomain" do
      let(:contact) do
        create(:contact, email_addresses_attributes: [{ address: "bob@mail.example.org", principal: true, kind: "work" }])
      end

      it "returns the full domain including the subdomain" do
        expect(contact.email_domain).to eq("mail.example.org")
      end
    end

    context "when the contact has no email addresses" do
      let(:contact) { create(:contact) }

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the primary email address is blank" do
      let(:contact) { create(:contact) }

      before do
        create(:email_address, resource: contact, address: "", principal: true, kind: "work")
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the email has no @ character" do
      let(:contact) { create(:contact) }

      before do
        create(:email_address, resource: contact, address: "notanemail", principal: true, kind: "work")
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the email ends with @" do
      let(:contact) { create(:contact) }

      before do
        create(:email_address, resource: contact, address: "user@", principal: true, kind: "work")
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the contact has multiple email addresses" do
      let(:contact) { create(:contact) }

      before do
        create(:email_address, resource: contact, address: "secondary@other.com", principal: false, kind: "personal")
        create(:email_address, resource: contact, address: "primary@acme.com", principal: true, kind: "work")
      end

      it "returns the domain from the principal email" do
        expect(contact.email_domain).to eq("acme.com")
      end
    end
  end
end
