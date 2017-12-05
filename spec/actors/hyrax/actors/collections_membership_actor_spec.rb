RSpec.describe Hyrax::Actors::CollectionsMembershipActor do
  let(:user) { create(:user) }
  let(:ability) { ::Ability.new(user) }
  let(:curation_concern) { create_for_repository(:work) }
  let(:attributes) { {} }
  let(:terminator) { Hyrax::Actors::Terminator.new }
  let(:change_set) { GenericWorkChangeSet.new(curation_concern) }
  let(:change_set_persister) { Hyrax::ChangeSetPersister.new(metadata_adapter: Valkyrie::MetadataAdapter.find(:indexing_persister), storage_adapter: Valkyrie.config.storage_adapter) }
  let(:env) { Hyrax::Actors::Environment.new(change_set, change_set_persister, ability, attributes) }

  subject(:middleware) do
    stack = ActionDispatch::MiddlewareStack.new.tap do |middleware|
      middleware.use described_class
      middleware.use Hyrax::Actors::GenericWorkActor
    end
    stack.build(terminator)
  end

  describe 'the next actor' do
    let(:attributes) do
      {
        member_of_collections_attributes: { '0' => { id: '123' } },
        title: ['test']
      }
    end

    before do
      allow(Collection).to receive(:find).with(['123'])
      allow(curation_concern).to receive(:member_of_collection_ids=)
    end

    it 'does not receive the member_of_collection_ids' do
      expect(terminator).to receive(:create).with(Hyrax::Actors::Environment) do |k|
        expect(k.attributes).to eq("title" => ["test"])
      end
      subject.create(env)
    end
  end

  describe 'create' do
    let(:collection) { create_for_repository(:collection, edit_users: [user.user_key]) }
    let(:attributes) do
      {
        member_of_collections_attributes: { '0' => { id: collection.id } },
        title: ['test']
      }
    end

    it 'adds it to the collection' do
      expect(subject.create(env)).to be true
      reloaded = Hyrax::Queries.find_by(id: collection.id)
      expect(reloaded.member_object_ids).to eq [curation_concern.id]
    end

    describe "when work is in user's own collection and destroy is passed" do
      let(:collection) { create_for_repository(:collection, user: user, title: ['A good title']) }
      let(:attributes) do
        { member_of_collections_attributes: { '0' => { id: collection.id, _destroy: 'true' } } }
      end
      let(:curation_concern) { create_for_repository(:work, member_of_collection_ids: [collection.id]) }

      it "removes the work from that collection" do
        expect(subject.create(env)).to be true
        expect(curation_concern.member_of_collection_ids).to eq []
      end
    end

    describe "when work is in another user's collection" do
      let(:other_collection) { create(:collection, title: ['A good title']) }
      let(:curation_concern) { create_for_repository(:work, member_of_collection_ids: [other_collection.id]) }

      it "doesn't remove the work from the other user's collection" do
        subject.create(env)
        expect(subject.create(env)).to be true
        expect(curation_concern.member_of_collection_ids).to match_array [collection.id, other_collection.id]
      end
    end
  end
end
