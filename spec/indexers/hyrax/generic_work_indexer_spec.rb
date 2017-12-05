RSpec.describe GenericWorkIndexer do
  subject(:solr_document) { service.generate_solr_document }

  # TODO: file_set_ids returns an empty set unless you persist the work
  let(:user) { create(:user) }
  let(:service) { described_class.new(work) }
  let(:work) { create_for_repository(:work) }

  context 'without explicit visibility set' do
    it 'indexes visibility' do
      expect(solr_document['visibility_ssi']).to eq 'restricted' # tight default
    end
  end

  context 'with explicit visibility set' do
    before { allow(work).to receive(:visibility).and_return('authenticated') }
    it 'indexes visibility' do
      expect(solr_document['visibility_ssi']).to eq 'authenticated'
    end
  end

  context "with child works" do
    let!(:work) { create_for_repository(:work_with_one_file, user: user) }
    let!(:child_work) { create_for_repository(:work, user: user) }
    let(:file) { work.file_sets.first }

    before do
      work.works << child_work
      allow(Hyrax::ThumbnailPathService).to receive(:call).and_return("/downloads/#{file.id}?file=thumbnail")
      work.representative_id = file.id
      work.thumbnail_id = file.id
    end

    it 'indexes member work and file_set ids' do
      expect(solr_document['member_ids_ssim']).to eq work.member_ids
      expect(solr_document['generic_type_sim']).to eq ['Work']
      expect(solr_document.fetch('thumbnail_path_ss')).to eq "/downloads/#{file.id}?file=thumbnail"
      expect(subject.fetch('hasRelatedImage_ssim').first).to eq file.id
      expect(subject.fetch('hasRelatedMediaFragment_ssim').first).to eq file.id
    end

    context "when thumbnail_field is configured" do
      before do
        service.thumbnail_field = 'thumbnail_url_ss'
      end
      it "uses the configured field" do
        expect(solr_document.fetch('thumbnail_url_ss')).to eq "/downloads/#{file.id}?file=thumbnail"
      end
    end
  end

  context "with an AdminSet" do
    let(:work) { create_for_repository(:work, admin_set: admin_set) }
    let(:admin_set) { create_for_repository(:admin_set, title: ['Title One']) }

    it "indexes the correct fields" do
      expect(solr_document.fetch('admin_set_sim')).to eq ["Title One"]
      expect(solr_document.fetch('admin_set_tesim')).to eq ["Title One"]
    end
  end

  context "the object status" do
    before { allow(work).to receive(:suppressed?).and_return(suppressed) }
    context "when suppressed" do
      let(:suppressed) { true }

      it "indexes the suppressed field with a true value" do
        expect(solr_document.fetch('suppressed_bsi')).to be true
      end
    end

    context "when not suppressed" do
      let(:suppressed) { false }

      it "indexes the suppressed field with a false value" do
        expect(solr_document.fetch('suppressed_bsi')).to be false
      end
    end
  end

  context "the actionable workflow roles" do
    let(:sipity_entity) do
      create(:sipity_entity, proxy_for_global_id: work.to_global_id.to_s)
    end

    before do
      allow(PowerConverter).to receive(:convert_to_sipity_entity).with(work).and_return(sipity_entity)
      allow(Hyrax::Workflow::PermissionQuery).to receive(:scope_roles_associated_with_the_given_entity)
        .and_return(['approve', 'reject'])
    end
    it "indexed the roles and state" do
      expect(solr_document.fetch('actionable_workflow_roles_ssim')).to eq [
        "#{sipity_entity.workflow.permission_template.admin_set_id}-#{sipity_entity.workflow.name}-approve",
        "#{sipity_entity.workflow.permission_template.admin_set_id}-#{sipity_entity.workflow.name}-reject"
      ]
      expect(solr_document.fetch('workflow_state_name_ssim')).to eq "initial"
    end
  end
end
