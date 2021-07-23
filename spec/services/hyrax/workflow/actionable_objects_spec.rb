# frozen_string_literal: true
RSpec.describe Hyrax::Workflow::ActionableObjects do
  subject(:service) { described_class.new(user: user) }
  let(:user) { FactoryBot.create(:user) }

  describe '#each' do
    it 'is empty by default' do
      expect(service.each).to be_none
    end

    context 'with objects in workflow' do
      let(:objects) do
        [FactoryBot.valkyrie_create(:hyrax_work, :with_default_admin_set),
         FactoryBot.valkyrie_create(:hyrax_work, :with_default_admin_set),
         FactoryBot.valkyrie_create(:hyrax_work, :with_default_admin_set)]
      end

      let(:permission_template) do
        Hyrax::PermissionTemplate
          .find_or_create_by(source_id: AdminSet::DEFAULT_ID)
      end

      let(:workflow_spec) do
        {
          workflows: [
            {
              name: "go_with_the_floe",
              label: "Testing out the workflow ",
              description: "A single-step workflow for the test suite",
              actions: [
                {
                  name: "ingest",
                  from_states: [],
                  transition_to: "needs_attention"
                },
                {
                  name: "two_step",
                  from_states: [
                    {
                      names: ["needs_attention"],
                      roles: ["disapproving"]
                    }
                  ],
                  transition_to: "not_the_magic_name",
                  methods: [
                    "Hyrax::Workflow::ActivateObject"
                  ]
                }
              ]
            }
          ]
        }
      end

      before do
        Hyrax::Workflow::WorkflowImporter
          .generate_from_hash(data: workflow_spec.as_json,
                              permission_template: permission_template)

        workflow = Sipity::Workflow.last
        Sipity::Workflow.activate!(permission_template: permission_template,
                                   workflow_id: workflow.id)

        objects.each { |o| Hyrax::Workflow::WorkflowFactory.create(o, {}, user) }
      end

      it 'is empty with no user actions' do
        expect(service.each).to be_none
      end

      context 'and user available actions' do
        before do
          agent = Sipity::Agent(user)
          Sipity::WorkflowRole.all.each do |wf_role|
            Sipity::WorkflowResponsibility.find_or_create_by!(agent_id: agent.id, workflow_role_id: wf_role.role_id)
            Sipity::WorkflowResponsibility.find_or_create_by!(agent_id: agent.id, workflow_role_id: wf_role.role_id)
          end
        end

        it 'lists the objects' do
          expect(service.map(&:id)).to contain_exactly(*objects.map(&:id))
        end
      end
    end
  end
end
