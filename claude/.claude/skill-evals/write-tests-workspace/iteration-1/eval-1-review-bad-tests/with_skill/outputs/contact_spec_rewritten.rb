# frozen_string_literal: true

require "spec_helper"

describe Contact do
  let(:user) { create(:user_owner) }

  before do
    Current.user = user
  end

  describe "tasks association" do
    let(:contact) { create(:contact) }

    it "includes tasks linked through source links" do
      task = create(:task)
      contact.source_links.create!(target: task)

      expect(contact.tasks).to include(task)
    end

    it "does not include tasks linked to other contacts" do
      other_contact = create(:contact)
      task = create(:task)
      other_contact.source_links.create!(target: task)

      expect(contact.tasks).not_to include(task)
    end
  end

  describe "#smart_destroy (soft delete)" do
    let(:contact) { create(:contact) }

    it "sets deleted_at on the contact" do
      expect { contact.smart_destroy }
        .to change { contact.reload.deleted_at }.from(nil)
    end

    it "does not permanently remove the record from the database" do
      contact.smart_destroy
      expect(Contact.with_deleted.find_by(id: contact.id)).to be_present
    end
  end

  describe "#full_name" do
    context "when the contact is a Person" do
      it "returns first and last name separated by a space" do
        contact = build(:contact, type: "Person", first_name: "Jane", last_name: "Smith")
        expect(contact.full_name).to eq("Jane Smith")
      end

      it "strips leading and trailing whitespace from the result" do
        contact = build(:contact, type: "Person", first_name: " Jane ", last_name: " Smith ")
        expect(contact.full_name).to eq("Jane  Smith")
      end

      it "returns just the last name when first_name is blank" do
        contact = build(:contact, type: "Person", first_name: nil, last_name: "Smith")
        expect(contact.full_name).to eq("Smith")
      end
    end

    context "when the contact is an Organization" do
      it "returns the organization name field" do
        contact = build(:organization, name: "Acme Corp")
        expect(contact.full_name).to eq("Acme Corp")
      end
    end
  end
end
