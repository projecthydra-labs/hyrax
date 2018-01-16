RSpec.describe Hyrax::Actors::FileActor do
  include ActionDispatch::TestProcess
  include Hyrax::FactoryHelpers

  let(:user)     { create(:user) }
  let(:file_set) { create_for_repository(:file_set) }
  let(:relation) { Valkyrie::Vocab::PCDMUse.OriginalFile }
  let(:actor)    { described_class.new(file_set, relation, user) }
  let(:fixture)  { fixture_file_upload('/world.png', 'image/png') }
  let(:huf) { Hyrax::UploadedFile.new(user: user, file: fixture) }
  let(:io) { JobIoWrapper.new(file_set_id: file_set.id, user: user, uploaded_file: huf, path: huf.uploader.path) }
  let(:storage_adapter) { Valkyrie::StorageAdapter.find(:disk) }
  let(:persister) { Valkyrie::MetadataAdapter.find(:indexing_persister).persister }
  let(:file_node) do
    node_builder = Hyrax::FileNodeBuilder.new(storage_adapter: storage_adapter, persister: persister)
    node = Hyrax::FileNode.for(file: fixture)
    node_builder.create(file: fixture, node: node, file_set: file_set)
  end

  context 'relation' do
    let(:relation) { RDF::URI.new("http://pcdm.org/use#remastered") }
    let(:file_set) { create_for_repository(:file_set) }

    it 'uses the relation from the actor' do
      expect(Hyrax::VersioningService).to receive(:create).with(Hyrax::FileNode, user)
      expect(CharacterizeJob).to receive(:perform_later)
      saved_node = actor.ingest_file(io)
      reloaded = Hyrax::Queries.find_by(id: file_set.id)
      expect(reloaded.member_by(use: relation).id).to eq saved_node.id
    end
  end

  it 'uses the provided mime_type' do
    allow(fixture).to receive(:content_type).and_return('image/gif')
    expect(Hyrax::VersioningService).to receive(:create).with(Hyrax::FileNode, user)
    expect(CharacterizeJob).to receive(:perform_later)
    saved_node = actor.ingest_file(io)
    expect(saved_node.mime_type).to eq ['image/gif']
  end

  context 'with two existing versions from different users' do
    let(:fixture2) { fixture_file_upload('/small_file.txt', 'text/plain') }
    let(:huf2) { Hyrax::UploadedFile.new(user: user2, file: fixture2) }
    let(:io2) { JobIoWrapper.new(file_set_id: file_set.id, user: user2, uploaded_file: huf2, path: huf2.uploader.path) }
    let(:user2) { create(:user) }
    let(:actor2) { described_class.new(file_set, relation, user2) }
    let(:versions) do
      reloaded = Hyrax::Queries.find_by(id: file_set.id)
      reloaded.original_file.versions
    end

    before do
      expect(Hyrax::VersioningService).to receive(:create).with(Hyrax::FileNode, user)
      expect(Hyrax::VersioningService).to receive(:create).with(Hyrax::FileNode, user2)
      expect(CharacterizeJob).to receive(:perform_later)
      actor.ingest_file(io)
      actor2.ingest_file(io2)
    end

    it 'has two versions' do
      expect(versions.all.count).to eq 2
      # the current version
      expect(file_set.original_file.mime_type).to eq 'text/plain'
      expect(file_set.original_file.original_name).to eq 'small_file.txt'
      expect(file_set.original_file.content).to eq fixture2.open.read
      # the user for each version
      expect(Hyrax::VersionCommitter.where(version_id: versions.first.uri).pluck(:committer_login)).to eq [user.user_key]
      expect(Hyrax::VersionCommitter.where(version_id: versions.last.uri).pluck(:committer_login)).to eq [user2.user_key]
    end
  end

  describe '#ingest_file' do
    it 'when the file is available' do
      expect(CharacterizeJob).to receive(:perform_later)
      actor.ingest_file(io)
      reloaded = Hyrax::Queries.find_by(id: file_set.id)
      expect(reloaded.member_by(use: relation)).not_to be_nil
    end
    # rubocop:disable RSpec/AnyInstance
    it 'returns false when save fails' do
      expect(CharacterizeJob).not_to receive(:perform_later)
      allow_any_instance_of(Hyrax::FileNodeBuilder).to receive(:create).and_raise(StandardError)
      expect(actor.ingest_file(io)).to be_falsey
    end
    # rubocop:enable RSpec/AnyInstance
  end

  describe '#revert_to' do
    let(:revision_id) { 'asdf1234' }

    before do
      allow(file_node).to receive(:restore_version).with(revision_id)
      allow(file_set).to receive(:original_file).and_return(file_node)
      allow(file_set).to receive(:member_by).with(use: relation).and_return(file_node)
      expect(CharacterizeJob).to receive(:perform_later).with(file_node.id.to_s)
    end

    it 'reverts to a previous version of a file' do
      expect(actor.relation).to eq(relation)
      actor.revert_to(revision_id)
    end

    describe 'for a different relation' do
      let(:relation) { RDF::URI.new("http://pcdm.org/use#remastered") }

      it 'reverts to a previous version of a file' do
        expect(actor.relation).to eq(relation)
        actor.revert_to(revision_id)
      end
      it 'does not rely on the default relation' do
        pending "Hydra::Works::VirusCheck must support other relations: https://github.com/samvera/hyrax/issues/1187"
        expect(actor.relation).to eq(relation)
        expect(file_set).not_to receive(:original_file)
        actor.revert_to(revision_id)
      end
    end
  end
end
