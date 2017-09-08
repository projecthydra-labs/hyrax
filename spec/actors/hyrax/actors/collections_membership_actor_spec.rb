RSpec.describe Hyrax::Actors::CollectionsMembershipActor do
  let(:user) { create(:user) }
  let(:ability) { ::Ability.new(user) }
  let(:curation_concern) { GenericWork.new }
  let(:attributes) { {} }
  let(:terminator) { Hyrax::Actors::Terminator.new }
  let(:env) { Hyrax::Actors::Environment.new(curation_concern, ability, attributes) }

  subject(:middleware) do
    stack = ActionDispatch::MiddlewareStack.new.tap do |middleware|
      middleware.use described_class
      middleware.use Hyrax::Actors::GenericWorkActor
    end
    stack.build(terminator)
  end

  describe 'the next actor' do
    let(:attributes) do
      { member_of_collection_ids: ['123'], title: ['test'] }
    end

    before do
      allow(Collection).to receive(:find).with(['123'])
      allow(curation_concern).to receive(:member_of_collections=)
    end

    it 'does not receive the member_of_collection_ids' do
      expect(terminator).to receive(:create).with(Hyrax::Actors::Environment) do |k|
        expect(k.attributes).to eq("title" => ["test"])
      end
      subject.create(env)
    end
  end

  describe 'create' do
    let(:collection) { create(:collection) }
    let(:attributes) do
      { member_of_collection_ids: [collection.id], title: ['test'] }
    end

    it 'adds it to the collection' do
      expect(subject.create(env)).to be true
      expect(collection.reload.member_objects).to eq [curation_concern]
    end

    context 'when multiple membership checker returns a non-nil value' do
      before do
        allow(Hyrax::MultipleMembershipChecker).to receive(:new).and_return(checker)
        allow(checker).to receive(:check).and_return(error_message)
      end

      let(:checker) { double('checker') }
      let(:error_message) { 'Error: foo bar' }

      it 'adds an error and returns false' do
        expect(env.curation_concern.errors).to receive(:add).with(:collections, error_message)
        expect(subject.create(env)).to be false
        expect(curation_concern.member_of_collections).to be_empty
      end
    end

    context "when work is in user's own collection" do
      let(:collection) { create(:collection, user: user, title: ['A good title']) }
      let(:attributes) { { member_of_collection_ids: [] } }

      before do
        subject.create(Hyrax::Actors::Environment.new(curation_concern, ability,
                                                      member_of_collection_ids: [collection.id], title: ['test']))
      end

      it "removes the work from that collection" do
        expect(subject.create(env)).to be true
        expect(curation_concern.member_of_collections).to eq []
      end
    end

    context "when work is in another user's collection" do
      let(:other_user) { create(:user) }
      let(:collection) { create(:collection, user: other_user, title: ['A good title']) }

      it "doesn't remove the work from that collection" do
        subject.create(env)
        expect(subject.create(env)).to be true
        expect(curation_concern.member_of_collections).to eq [collection]
      end
    end
  end
end
