require 'spec_helper'

RSpec.describe Hyrax::FileSetFixityCheckService do
  let(:f)                 { create(:file_set, content: File.open(fixture_path + '/world.png')) }
  let(:service_by_object) { described_class.new(f) }
  let(:service_by_id)     { described_class.new(f.id) }

  describe '#fixity_check' do
    context 'when a file has two versions' do
      before do
        Hyrax::VersioningService.create(f.original_file) # create a second version -- the factory creates the first version when it attaches +content+
      end
      subject { service_by_object.fixity_check[f.original_file.id] }
      specify 'returns two log results' do
        expect(subject.length).to eq(2)
      end
    end
  end

  describe '#fixity_check_file' do
    subject { service_by_object.send(:fixity_check_file, f.original_file) }
    specify 'returns a single result' do
      expect(subject.length).to eq(1)
    end
  end

  describe '#fixity_check_file_version' do
    subject { service_by_object.send(:fixity_check_file_version, f.original_file.id, f.original_file.uri) }
    specify 'returns a single ChecksumAuditLog for the given file' do
      expect(subject).to be_kind_of ChecksumAuditLog
      expect(subject.file_set_id).to eq(f.id)
      expect(subject.version).to eq(f.original_file.uri)
    end
  end

  describe '#fixity_check_stat' do
    subject { service_by_object.send(:fixity_check_stat, f.original_file) }
    context 'when no fixity checks have been run' do
      it 'reports that fixity checks have not been run' do
        expect(subject).to eq 'Fixity checks have not yet been run on this file.'
      end
    end

    context 'when no fixity check is pasing' do
      around do |example|
        original_adapter = ActiveJob::Base.queue_adapter
        ActiveJob::Base.queue_adapter = :inline
        example.run
        ActiveJob::Base.queue_adapter = original_adapter
      end

      before do
        Hyrax::VersioningService.create(f.original_file)
        ChecksumAuditLog.create!(pass: 1, file_set_id: f.id, version: f.original_file.versions.first.uri, file_id: 'original_file')
      end

      it 'reports that fixity checks have not been run' do
        expect(subject).to eq 'Some fixity checks have not been run, but the ones run were passing.'
      end
    end
  end

  describe '#human_readable_fixity_check_status' do
    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :inline
      example.run
      ActiveJob::Base.queue_adapter = original_adapter
    end

    before do
      Hyrax::VersioningService.create(f.original_file)
      ChecksumAuditLog.create!(pass: 1, file_set_id: f.id, version: f.original_file.versions.first.uri, file_id: 'original_file')
    end
    subject { service_by_object.human_readable_fixity_check_status }
    it { is_expected.to eq 'Some fixity checks have not been run, but the ones run were passing.' }
  end

  describe '#logged_fixity_status' do
    context "with an object" do
      subject { service_by_object.logged_fixity_status }

      it "doesn't trigger fixity checks" do
        expect(service_by_object).not_to receive(:fixity_check_file)
        expect(subject).to eq "Fixity checks have not yet been run on this file."
      end

      context "when no fixity check is passing" do
        before do
          ChecksumAuditLog.create!(pass: 1, file_set_id: f.id, version: f.original_file.versions.first.label, file_id: 'original_file')
        end

        it "reports the fixity check result" do
          expect(subject).to eq 'passing'
        end
      end

      context "when one fixity check is passing" do
        before do
          ChecksumAuditLog.create!(pass: 0, file_set_id: f.id, version: f.original_file.versions.first.label, file_id: 'original_file')
          ChecksumAuditLog.create!(pass: 1, file_set_id: f.id, version: f.original_file.versions.first.label, file_id: 'original_file')
        end

        it "reports the fixity check result" do
          expect(subject).to eq 'failing'
        end
      end
    end

    context "with an id" do
      subject { service_by_id.logged_fixity_status }

      before do
        ChecksumAuditLog.create!(pass: 1, file_set_id: f.id, version: f.original_file.versions.first.label, file_id: 'original_file')
      end

      it "reports the fixity result" do
        expect(subject).to eq 'passing'
      end
    end
  end

  describe '#stat_to_string' do
    subject { service_by_object.send(:stat_to_string, val) }
    context 'when fixity_stat is 0' do
      let(:val) { 0 }
      it { is_expected.to eq 'failing' }
    end

    context 'when fixity_stat is 1' do
      let(:val) { 1 }
      it { is_expected.to eq 'passing' }
    end

    context 'when fixity_stat is something else' do
      let(:val) { 'something else' }
      it "fails" do
        expect { subject }.to raise_error ArgumentError, "Unknown status `something else'"
      end
    end
  end
end
