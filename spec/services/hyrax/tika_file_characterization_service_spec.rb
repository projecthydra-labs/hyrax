include ActionDispatch::TestProcess

RSpec.describe Hyrax::TikaFileCharacterizationService do
  let(:file_characterization_service) { described_class }
  let(:adapter) { Valkyrie::MetadataAdapter.find(:indexing_persister) }
  let(:persister) { adapter.persister }
  let(:query_service) { adapter.query_service }
  let(:file) { fixture_file_upload('/world.png', 'image/png') }
  let(:valid_file_set) { create_for_repository(:file_set, content: file) }
  let(:file_node) { valid_file_set.original_file }

  before do
    output = '547c81b080eb2d7c09e363a670c46960ac15a6821033263867dd59a31376509c'
    ruby_mock = instance_double(Digest::SHA256, hexdigest: output)
    allow(Digest::SHA256).to receive(:hexdigest).and_return(ruby_mock)
  end

  it 'characterizes a sample file' do
    described_class.new(file_node: file_node, persister: persister).characterize
  end

  it 'sets the height attribute for a file_node on characterize ' do
    file_node.height = nil
    new_file_node = described_class.new(file_node: file_node, persister: persister).characterize
    expect(new_file_node.height).not_to be_empty
  end

  it 'sets the width attribute for a file_node on characterize' do
    file_node.width = nil
    new_file_node = described_class.new(file_node: file_node, persister: persister).characterize
    expect(new_file_node.width).not_to be_empty
  end

  it 'saves to the persister by default on characterize' do
    allow(persister).to receive(:save).and_return(file_node)
    described_class.new(file_node: file_node, persister: persister).characterize
    expect(persister).to have_received(:save).exactly(2).times
  end

  it 'sets the mime_type for a file_node on characterize' do
    file_node.mime_type = nil
    new_file_node = described_class.new(file_node: file_node, persister: persister).characterize
    expect(new_file_node.mime_type).not_to be_empty
  end

  it 'sets the checksum for a file_node on characterize' do
    file_node.checksum = nil
    new_file_node = described_class.new(file_node: file_node, persister: persister).characterize
    expect(new_file_node.checksum.count).to eq 1
    expect(new_file_node.checksum.first).to be_a Hyrax::MultiChecksum
  end

  describe "#valid?" do
    it "returns true" do
      expect(described_class.new(file_node: file_node, persister: persister).valid?).to be true
    end
  end
end
