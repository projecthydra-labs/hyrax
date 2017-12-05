RSpec.describe Collection do
  let(:collection) { build(:public_collection) }
  let(:persister) { Valkyrie.config.metadata_adapter.persister }

  it "has open visibility" do
    expect(collection.read_groups).to eq ['public']
  end

  describe "#validates_with" do
    before { collection.title = nil }
    it "ensures the collection has a title" do
      expect(collection).not_to be_valid
      expect(collection.errors.messages[:title]).to eq(["You must provide a title"])
    end
  end

  describe "#to_solr" do
    let(:user) { build(:user) }
    let(:collection) { build(:collection, user: user, title: ['A good title']) }

    let(:solr_document) { collection.to_solr }

    it "has title information and depositor information" do
      expect(solr_document).to include 'title_tesim' => ['A good title'],
                                       'title_sim' => ['A good title'],
                                       'depositor_tesim' => [user.user_key],
                                       'depositor_ssim' => [user.user_key]
    end
  end

  describe "#depositor" do
    let(:user) { build(:user) }

    before do
      subject.apply_depositor_metadata(user)
    end

    it "has a depositor" do
      expect(subject.depositor).to eq(user.user_key)
    end
  end

  describe "#members_objects", clean_repo: true do
    let(:collection) { create(:collection) }

    it "is empty by default" do
      expect(collection.member_objects).to match_array []
    end

    context "adding members" do
      let(:work1) { create_for_repository(:work) }
      let(:work2) { create_for_repository(:work) }

      it "allows multiple files to be added" do
        collection.add_member_objects [work1.id, work2.id]
        collection.save!
        expect(collection.reload.member_objects).to match_array [work1, work2]
      end
    end
  end

  describe "#destroy", clean_repo: true do
    let(:collection) { build(:collection) }
    let(:work1) { create_for_repository(:work) }

    before do
      collection.add_member_objects [work1.id]
      collection.save!
      collection.destroy
    end

    it "does not delete member files when deleted" do
      expect(GenericWork.exists?(work1.id)).to be true
    end
  end

  describe "Collection by another name" do
    before do
      class OtherCollection < Valkyrie::Resource
        include Hyrax::CollectionBehavior
      end

      class Member < Valkyrie::Resource
        include Hyrax::WorkBehavior
      end
      collection.add_member_objects member.id
    end
    after do
      Object.send(:remove_const, :OtherCollection)
      Object.send(:remove_const, :Member)
    end

    let(:member) { persister.save(resource: Member.new) }
    let(:collection) do
      col = OtherCollection.new(title: ['test title'])
      persister.save(resource: col)
    end

    it "have members that know about the collection", clean_repo: true do
      member.reload
      expect(member.member_of_collection_ids).to eq [collection.id]
    end
  end
end
