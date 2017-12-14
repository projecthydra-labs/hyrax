RSpec.describe Hyrax::Workflow::StatusListService do
  let(:user) { create(:user) }
  let(:context) { double(current_user: user, logger: double(debug: nil)) }
  let(:service) { described_class.new(context, "workflow_state_name_ssim:initial") }

  describe '#repository' do
    let(:repository) { service.repository }

    it 'queries Solr via HTTP POST method' do
      expect(repository.blacklight_config.http_method).to eq :post
    end
  end

  describe "#each" do
    let!(:sipity_entity) { create(:sipity_entity) }
    let(:document) do
      { id: '33333',
        Valkyrie::Persistence::Solr::Queries::MODEL => ['GenericWork'],
        actionable_workflow_roles_ssim: ["foobar-generic_work-approving", "foobar-generic_work-rejecting"],
        workflow_state_name_ssim: ["initial"],
        title_tesim: ['Hey dood!'] }
    end
    let(:ability) do
      { id: '44444',
        Valkyrie::Persistence::Solr::Queries::MODEL => ['GenericWork'],
        title_tesim: ['bad result'] }
    end
    let(:workflow_role) { instance_double(Sipity::Role, name: 'approving') }
    let(:workflow_roles) { [instance_double(Sipity::WorkflowRole, role: workflow_role)] }
    let(:results) { service.each.to_a }
    let(:solr) { Valkyrie::MetadataAdapter.find(:index_solr).connection }

    before do
      solr.add([document, ability], params: { commit: true })
    end

    context "when user has roles" do
      let(:template) { double('template', admin_set_id: 'foobar') }
      let(:workflow) do
        instance_double(Sipity::Workflow, name: 'generic_work', permission_template: template)
      end

      before do
        allow(Hyrax::Workflow::PermissionQuery).to receive(:scope_processing_workflow_roles_for_user_and_workflow).and_return(workflow_roles)
        allow(Sipity::Workflow).to receive(:all).and_return([workflow])
      end

      it "returns status rows" do
        expect(results.size).to eq 1
        expect(results.first).to be_kind_of(SolrDocument)
        expect(results.first.to_s).to eq 'Hey dood!'
        expect(results.first.workflow_state).to eq 'initial'
      end
    end

    context "when user doesn't have roles" do
      before do
        allow(Hyrax::Workflow::PermissionQuery).to receive(:scope_processing_workflow_roles_for_user_and_workflow).and_return([])
      end
      it "returns nothing" do
        expect(results).to be_empty
      end
    end
  end
end
