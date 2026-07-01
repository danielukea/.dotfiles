# frozen_string_literal: true

require "spec_helper"

describe Contact do
  let(:user) { create(:user_owner) }

  before do
    Current.user = user
  end

  describe "tasks association" do
    let(:contact) { create(:person, creator: user) }

    it "includes tasks linked to the contact via source links" do
      task = create(:task, link_to: contact)
      expect(contact.tasks).to include(task)
    end

    it "does not include tasks linked to a different contact" do
      other_contact = create(:person, creator: user)
      task = create(:task, link_to: other_contact)
      expect(contact.tasks).not_to include(task)
    end
  end

  describe "#smart_destroy (soft-delete via TrashCanRecoverable)" do
    let(:contact) { create(:person, creator: user) }

    it "soft-deletes the contact by setting deleted_at" do
      expect { contact.smart_destroy }
        .to change { contact.reload.deleted_at }.from(nil)
    end

    it "removes the contact from the default scope" do
      contact.smart_destroy
      expect(Contact.where(id: contact.id)).to be_empty
    end
  end

  describe "#full_name" do
    context "when the contact is a Person" do
      it "returns first and last name joined by a space" do
        person = build(:person, first_name: "Jane", last_name: "Smith")
        expect(person.full_name).to eq("Jane Smith")
      end

      it "strips leading and trailing whitespace from the result" do
        person = build(:person, first_name: "  Jane  ", last_name: "  Smith  ")
        expect(person.full_name).to eq("Jane Smith")
      end

      it "returns an empty string when both first and last name are blank" do
        person = build(:person, first_name: nil, last_name: nil)
        expect(person.full_name).to eq("")
      end
    end

    context "when the contact is an Organization" do
      it "returns the organization's name" do
        org = build(:organization, name: "Acme Corp")
        expect(org.full_name).to eq("Acme Corp")
      end
    end

    context "when the contact is a Household" do
      it "returns the household name" do
        household = build(:household, name: "Smith Family")
        expect(household.full_name).to eq("Smith Family")
      end
    end
  end
end
