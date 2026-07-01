require "spec_helper"

describe Contact do
  it { is_expected.to have_many(:tasks) }

  describe "#full_name" do
    context "without a middle name" do
      it "returns first and last name separated by a space" do
        contact = build(:contact, first_name: "Jane", middle_name: nil, last_name: "Smith")
        expect(contact.full_name).to eq("Jane Smith")
      end
    end

    context "with a middle name" do
      it "includes the middle name between first and last" do
        contact = build(:contact, first_name: "Jane", middle_name: "Marie", last_name: "Smith")
        expect(contact.full_name).to eq("Jane Marie Smith")
      end
    end
  end

  describe "#archive!" do
    it "marks the contact as archived" do
      contact = create(:contact)
      expect { contact.archive! }.to change { contact.reload.archived? }.from(false).to(true)
    end
  end
end
