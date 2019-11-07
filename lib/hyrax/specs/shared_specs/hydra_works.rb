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

RSpec.shared_examples 'a Hyrax::AdministrativeSet' do
  subject(:admin_set) { described_class.new }

  it 'has an #alternative_title' do
    expect { admin_set.alternative_title = ['Moomin'] }
      .to change { admin_set.alternative_title }
      .to contain_exactly('Moomin')
  end

  it 'has an #creator' do
    expect { admin_set.creator = ['user1'] }
      .to change { admin_set.creator }
      .to contain_exactly('user1')
  end

  it 'has an #description' do
    expect { admin_set.description = ['lorem ipsum'] }
      .to change { admin_set.description }
      .to contain_exactly('lorem ipsum')
  end

  it 'has an #title' do
    expect { admin_set.title = ['Moomin'] }
      .to change { admin_set.title }
      .to contain_exactly('Moomin')
  end
end

RSpec.shared_examples 'a Hyrax::Work' do
  subject(:work)      { described_class.new }
  let(:adapter)       { Valkyrie::MetadataAdapter.find(:test_adapter) }
  let(:persister)     { adapter.persister }
  let(:query_service) { adapter.query_service }

  it_behaves_like 'a Hyrax::Resource'
  it_behaves_like 'a model with core metadata'
  it_behaves_like 'has members'

  it { is_expected.not_to be_collection }
  it { is_expected.not_to be_file }
  it { is_expected.not_to be_file_set }
  it { is_expected.to be_pcdm_object }
  it { is_expected.to be_work }

  describe '#admin_set_id' do
    it 'is nil by default' do
      expect(work.admin_set_id).to be_nil
    end

    it 'has admin_set_id' do
      expect { work.admin_set_id = 'admin_set_1' }
        .to change { work.admin_set_id&.id }
        .to 'admin_set_1'
    end

    context 'with a saved admin set' do
      let(:admin_set) { persister.save(resource: Hyrax::AdministrativeSet.new) }

      before { work.admin_set_id = admin_set.id }

      it 'can query admin set' do
        saved = persister.save(resource: work)

        expect(query_service.find_references_by(resource: saved, property: :admin_set_id))
          .to contain_exactly admin_set
      end
    end
  end
end

RSpec.shared_examples 'a Hyrax::FileSet' do
  subject(:fileset)   { described_class.new }
  let(:adapter)       { Valkyrie::MetadataAdapter.find(:test_adapter) }
  let(:persister)     { adapter.persister }
  let(:query_service) { adapter.query_service }

  it_behaves_like 'a Hyrax::Resource'
  it_behaves_like 'a model with core metadata'

  it { is_expected.not_to be_collection }
  it { is_expected.not_to be_file }
  it { is_expected.to be_file_set }
  it { is_expected.to be_pcdm_object }
  it { is_expected.not_to be_work }

  describe 'files' do
    it 'has empty file_ids by default' do
      expect(fileset.file_ids).to be_empty
    end

    it 'has empty files by default' do
      expect(query_service.custom_queries.find_files(file_set: fileset)).to be_empty
    end

    context 'with files' do
      let(:file_class) { Hyrax::FileMetadata }
      let(:files) do
        [file_class.new, file_class.new, file_class.new]
          .map! { |f| persister.save(resource: f) }
      end

      let(:file_ids) { files.map(&:id) }

      before { fileset.file_ids = file_ids }

      it 'has file_ids' do
        expect(fileset.file_ids).to eq file_ids
      end

      it 'can query files' do
        expect(query_service.custom_queries.find_files(file_set: fileset)).to eq files
      end

      it 'can not have the same file multiple times' do
        expect { fileset.file_ids << file_ids.first }
          .not_to change { query_service.custom_queries.find_files(file_set: fileset) }
      end
    end
  end

  describe 'original file' do
    it 'has nil original_file_id by default' do
      expect(fileset.original_file_id).to be_nil
    end

    context 'with original file' do
      let(:file_class) { Hyrax::FileMetadata }
      let(:original_file) { persister.save(resource: file_class.new) }
      let(:original_file_id) { original_file.id }
      let(:second_file) { persister.save(resource: file_class.new) }

      before { fileset.original_file_id = original_file_id }

      it 'has original_file_id' do
        expect(fileset.original_file_id).to eq original_file_id
      end

      it 'can query original file' do
        expect(query_service.custom_queries.find_original_file(file_set: fileset)).to eq original_file
      end
    end
  end

  describe 'extracted text' do
    it 'has nil extracted_text_id by default' do
      expect(fileset.extracted_text_id).to be_nil
    end

    context 'with extracted text' do
      let(:file_class) { Hyrax::FileMetadata }
      let(:extracted_text) { persister.save(resource: file_class.new) }
      let(:extracted_text_id) { extracted_text.id }
      let(:second_file) { persister.save(resource: file_class.new) }

      before { fileset.extracted_text_id = extracted_text_id }

      it 'has extracted_text_id' do
        expect(fileset.extracted_text_id).to eq extracted_text_id
      end

      it 'can query extracted text' do
        expect(query_service.custom_queries.find_extracted_text(file_set: fileset)).to eq extracted_text
      end
    end
  end

  describe 'thumbnail' do
    it 'has nil thumbnail_id by default' do
      expect(fileset.thumbnail_id).to be_nil
    end

    context 'with thumbnail' do
      let(:file_class) { Hyrax::FileMetadata }
      let(:thumbnail) { persister.save(resource: file_class.new) }
      let(:thumbnail_id) { thumbnail.id }
      let(:second_file) { persister.save(resource: file_class.new) }

      before { fileset.thumbnail_id = thumbnail_id }

      it 'has thumbnail_id' do
        expect(fileset.thumbnail_id).to eq thumbnail_id
      end

      it 'can query thumbnail' do
        expect(query_service.custom_queries.find_thumbnail(file_set: fileset)).to eq thumbnail
      end
    end
  end
end
