# frozen_string_literal: true
require 'spicy_wings_helper'
require 'spicy_wings/services/file_converter_service'

RSpec.describe SpicyWings::FileConverterService do
  let(:af_file_id) { af_file.id }
  let(:af_attrs) { plain_text_af_attrs }
  let(:af_file) do
    aff = Hydra::PCDM::File.new(id: 'af_1')
    aff.original_name = plain_text_af_attrs[:original_name]
    aff.mime_type = plain_text_af_attrs[:mime_type]
    aff.content = plain_text_af_attrs[:content]
    aff.format_label = plain_text_af_attrs[:format_label]
    aff.language = plain_text_af_attrs[:language]
    aff.word_count = plain_text_af_attrs[:content].split(' ').count
    aff.character_count = plain_text_af_attrs[:content].size
    aff.save
    aff
  end

  describe '#af_file_to_resource' do
    subject { described_class.af_file_to_resource(af_file: af_file) }
    it 'copies attributes to resource' do # rubocop:disable RSpec/ExampleLength
      expect(subject.id.to_s).to eq af_file_id
      expect(subject.alternate_ids).to match_valkyrie_ids_with_active_fedora_ids [af_file_id]
      expect(subject.file_identifiers).to match_valkyrie_ids_with_active_fedora_ids [af_file_id]
      expect(subject.created_at).to eq af_file.create_date
      expect(subject.updated_at).to eq af_file.modified_date
      expect(subject.original_filename).to eq Array(plain_text_af_attrs[:original_name])
      expect(subject.mime_type).to eq Array(plain_text_af_attrs[:mime_type])
      expect(subject.content).to eq Array(plain_text_af_attrs[:content])
      expect(subject.format_label).to eq Array(plain_text_af_attrs[:format_label])
      expect(subject.language).to eq Array(plain_text_af_attrs[:language])
      expect(subject.word_count).to eq Array(plain_text_af_attrs[:content].split(' ').count)
      expect(subject.size).to eq Array(plain_text_af_attrs[:content].size)
      expect(subject.character_count).to eq Array(plain_text_af_attrs[:content].size)
    end
  end

  describe '#resource_to_af_file' do
    let(:id) { 'val_2' }
    let(:valkyrie_id) { ::Valkyrie::ID.new(id) }
    let(:valkyrie_attrs) { plain_text_valkyrie_attrs }
    let(:file_metadata) do
      valkyrie_attrs[:alternate_ids] = valkyrie_id
      valkyrie_attrs[:file_identifiers] = valkyrie_id
      valkyrie_attrs[:word_count] = plain_text_valkyrie_attrs[:content].split(' ').count
      valkyrie_attrs[:size] = plain_text_valkyrie_attrs[:content].size
      valkyrie_attrs[:character_count] = plain_text_valkyrie_attrs[:content].size
      Hyrax::FileMetadata.new(id: valkyrie_id, **valkyrie_attrs)
    end
    subject { described_class.resource_to_af_file(metadata_resource: file_metadata) }
    it 'copies attributes to af_file' do
      expect(subject.id.to_s).to eq id
      expect(subject.original_name).to eq plain_text_valkyrie_attrs[:original_filename]
      validate_af_file_metadata(plain_text_valkyrie_attrs)
    end
  end

  context 'round trip conversion from af_file to resource to af_file' do
    let(:file_metadata) { described_class.af_file_to_resource(af_file: af_file) }
    subject { described_class.resource_to_af_file(metadata_resource: file_metadata) }
    it 'copies attributes to af_file' do
      expect(subject.id.to_s).to eq af_file_id
      expect(subject.create_date).to eq af_file.create_date
      expect(subject.modified_date).not_to eq af_file.modified_date
      expect(subject.original_name).to eq plain_text_af_attrs[:original_name]
      validate_af_file_metadata(plain_text_af_attrs)
    end
  end

  private

    def validate_af_file_metadata(expected_attrs) # rubocop:disable Metrics/AbcSize
      expect(subject.mime_type).to eq expected_attrs[:mime_type]
      expect(subject.content).to eq expected_attrs[:content]
      expect(subject.format_label).to eq Array(expected_attrs[:format_label])
      expect(subject.language).to eq Array(expected_attrs[:language])
      expect(subject.word_count).to eq Array(expected_attrs[:content].split(' ').count)
      expect(subject.size).to eq expected_attrs[:content].size
      expect(subject.character_count).to eq Array(expected_attrs[:content].size)
    end

    def plain_text_af_attrs
      { original_name: 'my_file.txt',
        mime_type: 'text/plain',
        content: 'some text content for af_file_to_resource test',
        format_label: 'Plain Text',
        language: 'en' }
    end

    def plain_text_valkyrie_attrs
      { original_filename: 'my_file.html',
        mime_type: 'text/html',
        content: '<h3>different text content for valkyrie_to_af_file test</h3>',
        format_label: 'HTML Text',
        language: 'en',
        created_at: Time.now.getlocal - 5.days,
        updated_at: Time.now.getlocal }
    end
end
