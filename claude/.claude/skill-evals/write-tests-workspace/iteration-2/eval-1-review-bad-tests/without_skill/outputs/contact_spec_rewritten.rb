# frozen_string_literal: true

require "spec_helper"

describe Contact do
  let(:user) { create(:user_owner) }

  before { Current.user = user }

  # PrimaryDocument concern wires tasks through source_links — test the behavior,
  # not the has_many declaration.
  describe "tasks association" do
    it "returns tasks linked to the contact" do
      contact = create(:contact)
      task = create(:task)
      contact.source_links.create!(target: task)

      expect(contact.tasks).to include(task)
    end

    it "does not return tasks linked to a different contact" do
      contact = create(:contact)
      other_contact = create(:contact)
      task = create(:task)
      other_contact.source_links.create!(target: task)

      expect(contact.tasks).to be_empty
    end
  end

  # Email is not a column on contacts — it lives in email_addresses.
  # Test the relationship behavior instead.
  describe "email addresses" do
    it "can have many email addresses" do
      contact = create(:contact_with_primary_email)

      expect(contact.email_addresses).not_to be_empty
    end
  end

  # Contact uses TrashCanRecoverable (soft-delete via acts_as_paranoid).
  # There is no archive! method — test smart_destroy, which is the soft-delete entry point.
  describe "soft delete via TrashCanRecoverable" do
    it "soft-deletes by setting deleted_at" do
      contact = create(:contact)

      expect { contact.smart_destroy }.to change { contact.reload.deleted_at }.from(nil)
    end

    it "excludes soft-deleted contacts from the default scope" do
      contact = create(:contact)
      contact.smart_destroy

      expect(Contact.all).not_to include(contact)
    end

    it "surfaces soft-deleted contacts via only_deleted" do
      contact = create(:contact)
      contact.smart_destroy

      expect(Contact.only_deleted).to include(contact)
    end
  end

  # Test that saving a contact triggers search index reindexing rather than asserting
  # the callback is registered. We verify the side-effect, not the wiring.
  describe "search index update on save" do
    it "enqueues a reindex job after saving" do
      contact = build(:contact)

      expect { contact.save! }.to have_enqueued_job(OpenSearch::IndexDocumentJob)
        .with(contact.class.name, anything)
    end

    it "enqueues a reindex job when a contact attribute changes" do
      contact = create(:contact)

      expect { contact.update!(first_name: "Updated") }.to have_enqueued_job(OpenSearch::IndexDocumentJob)
        .with(contact.class.name, anything)
    end
  end

  describe "#full_name" do
    context "when the contact is a Person" do
      it "concatenates first_name and last_name" do
        person = build(:person, first_name: "Jane", last_name: "Smith")

        expect(person.full_name).to eq("Jane Smith")
      end

      it "strips leading and trailing whitespace" do
        person = build(:person, first_name: "Jane", last_name: "Smith")
        allow(person).to receive(:first_name).and_return("  Jane  ")
        allow(person).to receive(:last_name).and_return("  Smith  ")

        expect(person.full_name).to eq("Jane    Smith")
      end

      it "handles a blank last name" do
        person = build(:person, first_name: "Madonna", last_name: nil)

        expect(person.full_name).to eq("Madonna")
      end

      it "handles a blank first name" do
        person = build(:person, first_name: nil, last_name: "Cher")

        expect(person.full_name).to eq("Cher")
      end
    end

    context "when the contact is an Organization" do
      it "returns the organization name" do
        org = build(:organization, name: "Acme Corp")

        expect(org.full_name).to eq("Acme Corp")
      end

      it "returns an empty string when name is nil" do
        org = build(:organization, name: nil)

        expect(org.full_name).to eq("")
      end
    end
  end
end
