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
        create(:contact).tap do |c|
          create(:email_address, resource: c, address: "alice@acme.com", principal: true)
        end
      end

      it "returns the domain part of the email" do
        expect(contact.email_domain).to eq("acme.com")
      end
    end

    context "when the contact has a primary email with a subdomain" do
      let(:contact) do
        create(:contact).tap do |c|
          create(:email_address, resource: c, address: "bob@mail.example.org", principal: true)
        end
      end

      it "returns the full domain including subdomain" do
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
      let(:contact) do
        create(:contact).tap do |c|
          create(:email_address, resource: c, address: "", principal: true)
        end
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the email has no @ symbol" do
      let(:contact) do
        create(:contact).tap do |c|
          create(:email_address, resource: c, address: "notanemail", principal: true)
        end
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end

    context "when the email ends with @" do
      let(:contact) do
        create(:contact).tap do |c|
          create(:email_address, resource: c, address: "user@", principal: true)
        end
      end

      it "returns nil" do
        expect(contact.email_domain).to be_nil
      end
    end
  end
end
