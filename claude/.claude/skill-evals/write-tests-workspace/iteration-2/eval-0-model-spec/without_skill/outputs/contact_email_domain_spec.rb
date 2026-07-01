# frozen_string_literal: true

require "spec_helper"

describe Contact do
  let(:user) { create :user_owner }

  before do
    Current.user = user
  end

  describe "#email_domain" do
    subject(:contact) { create :person }

    context "when the contact has a primary email with a domain" do
      before do
        contact.email_addresses << create(:email_address, address: "alice@acme.com", principal: true)
      end

      it "returns the domain part of the email" do
        expect(contact.email_domain).to eq("acme.com")
      end
    end

    context "when the contact has a primary email with a subdomain" do
      before do
        contact.email_addresses << create(:email_address, address: "bob@mail.example.org", principal: true)
      end

      it "returns the full domain including subdomains" do
        expect(contact.email_domain).to eq("mail.example.org")
      end
    end

    context "when the contact has no email addresses" do
      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the primary email is blank" do
      before do
        contact.email_addresses << create(:email_address, address: "", principal: true)
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the primary email has no @ symbol" do
      before do
        contact.email_addresses << create(:email_address, address: "notanemail", principal: true)
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the primary email ends with @" do
      before do
        contact.email_addresses << create(:email_address, address: "user@", principal: true)
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end
  end
end
