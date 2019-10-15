require 'valkyrie/specs/shared_specs'
require 'hyrax/specs/shared_specs/metadata'

RSpec.shared_examples 'a Hyrax::Resource' do
  subject(:resource) { described_class.new }
  let(:adapter)      { Valkyrie::MetadataAdapter.find(:test_adapter) }

  it_behaves_like 'a Valkyrie::Resource' do
    let(:resource_klass) { described_class }
  end

  describe '#alternate_ids' do
    let(:id) { Valkyrie::ID.new('fake_identifier') }

    it 'has an attribute for alternate ids' do
      expect { resource.alternate_ids = id }
        .to change { resource.alternate_ids }
        .to contain_exactly id
    end
  end

  it { is_expected.to respond_to :collection? }
  it { is_expected.to respond_to :file? }
  it { is_expected.to respond_to :file_set? }
  it { is_expected.to respond_to :pcdm_object? }
  it { is_expected.to respond_to :work? }
end

RSpec.shared_examples 'has members' do
  subject(:model)     { described_class.new }
  let(:adapter)       { Valkyrie::MetadataAdapter.find(:test_adapter) }
  let(:persister)     { adapter.persister }
  let(:query_service) { adapter.query_service }

  describe 'members' do
    it 'has empty member_ids by default' do
      expect(model.member_ids).to be_empty
    end

    it 'has empty members by default' do
      expect(query_service.find_members(resource: model)).to be_empty
    end

    context 'with members' do
      let(:member_works) do
        [described_class.new, described_class.new, described_class.new]
          .map! { |w| persister.save(resource: w) }
      end

      let(:member_ids) { member_works.map(&:id) }

      before { model.member_ids = member_ids }

      it 'has member_ids' do
        expect(model.member_ids).to eq member_ids
      end

      it 'can query members' do
        expect(query_service.find_members(resource: model)).to eq member_works
      end

      it 'can have the same member multiple times' do
        expect { model.member_ids << member_ids.first }
          .to change { query_service.find_members(resource: model) }
          .to eq(member_works + [member_works.first])
      end
    end
  end
end

RSpec.shared_examples 'a Hyrax::PcdmCollection' do
  subject(:collection) { described_class.new }

  it_behaves_like 'a Hyrax::Resource'
  it_behaves_like 'a model with core metadata'
  it_behaves_like 'has members'

  describe '#collection_type_gid' do
    let(:gid) { Hyrax::CollectionType.find_or_create_default_collection_type.to_global_id.to_s }

    it 'has a GlobalID for a collection type' do
      expect { collection.collection_type_gid = gid }
        .to change { collection.collection_type_gid }
        .to gid
    end
  end
end

RSpec.shared_examples 'a Hyrax::Work' do
  subject(:work)      { described_class.new }

  it_behaves_like 'a Hyrax::Resource'
  it_behaves_like 'a model with core metadata'
  it_behaves_like 'has members'

  it { is_expected.not_to be_collection }
  it { is_expected.not_to be_file }
  it { is_expected.not_to be_file_set }
  it { is_expected.to be_pcdm_object }
  it { is_expected.to be_work }
end
