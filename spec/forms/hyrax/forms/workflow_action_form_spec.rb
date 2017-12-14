RSpec.describe Hyrax::Forms::WorkflowActionForm do
  let(:work) { create_for_repository(:work) }
  let(:sipity_entity) do
    create(:sipity_entity, proxy_for_global_id: work.to_global_id.to_s, workflow_state_id: 2)
  end
  let(:user) { create(:user) }
  let(:current_ability) { double(current_user: user) }
  let(:form) do
    described_class.new(current_ability: current_ability,
                        work: work,
                        attributes: { name: 'an_action', comment: 'a_comment' },
                        persister: persister)
  end
  let(:persister) { Valkyrie::MetadataAdapter.find(:indexing_persister).persister }

  let(:an_action) do
    instance_double(Sipity::WorkflowAction,
                    resulting_workflow_state_id: 3,
                    notifiable_contexts: [],
                    triggered_methods: Sipity::Method.none)
  end

  context 'if the given user cannot perform the given action' do
    before do
      allow(PowerConverter).to receive(:convert_to_sipity_action).with('an_action', scope: sipity_entity.workflow).and_return(an_action)
      expect(Hyrax::Workflow::PermissionQuery).to receive(:authorized_for_processing?).and_return(false)
    end

    describe '#valid?' do
      subject { form.valid? }

      it { is_expected.to be false }
    end

    describe '#save' do
      subject { form.save }

      it { is_expected.to be false }

      it 'will not add a comment' do
        expect { form.save }.not_to change { Sipity::Comment.count }
      end

      it 'will not send the #deliver_on_action_taken message to Hyrax::Workflow::NotificationService' do
        expect(Hyrax::Workflow::NotificationService).not_to receive(:deliver_on_action_taken)
        subject
      end

      it 'will not send the #handle_action_taken message to Hyrax::Workflow::ActionTakenService' do
        expect(Hyrax::Workflow::ActionTakenService).not_to receive(:handle_action_taken)
        subject
      end
    end
  end

  context 'if the given user can perform the given action' do
    before do
      allow(PowerConverter).to receive(:convert_to_sipity_action).with('an_action', scope: sipity_entity.workflow).and_return(an_action)
      expect(Hyrax::Workflow::PermissionQuery).to receive(:authorized_for_processing?)
        .and_return(true)
    end

    describe '#valid?' do
      subject { form.valid? }

      it { is_expected.to eq(true) }
    end

    describe '#save' do
      subject { form.save }

      it { is_expected.to be true }

      context 'and the action has a resulting_workflow_state_id' do
        it 'will update the state of the given work and index it' do
          expect_any_instance_of(Valkyrie::MetadataAdapter.find(:index_solr).persister.class).to receive(:save).with(resource: form.work)
          expect { subject }.to change { sipity_entity.reload.workflow_state_id }.from(2).to(an_action.resulting_workflow_state_id)
        end
      end

      context 'and the action does not have a resulting_workflow_state_id' do
        let(:an_action) do
          instance_double(Sipity::WorkflowAction,
                          resulting_workflow_state_id: nil,
                          notifiable_contexts: [],
                          triggered_methods: Sipity::Method.none)
        end

        it 'will not update the state of the given work' do
          expect { subject }.not_to change { sipity_entity.reload.workflow_state_id }
        end
      end

      it 'will create the given comment for the entity' do
        expect { subject }.to change { Sipity::Comment.count }.by(1)
      end

      it 'will send the #deliver_on_action_taken message to Hyrax::Workflow::NotificationService' do
        expect(Hyrax::Workflow::NotificationService).to(
          receive(:deliver_on_action_taken).with(entity: sipity_entity, comment: kind_of(Sipity::Comment), action: an_action, user: user)
        )
        subject
      end

      it 'will send the #handle_action_taken message to Hyrax::Workflow::ActionTakenService' do
        expect(Hyrax::Workflow::ActionTakenService).to(
          receive(:handle_action_taken).with(target: work, comment: kind_of(Sipity::Comment), action: an_action, user: user, persister: persister)
        )
        subject
      end
    end
  end

  context 'when no option is selected upon initialization' do
    before do
      sipity_entity
    end
    let(:form) do
      described_class.new(current_ability: current_ability,
                          work: work,
                          attributes: { comment: '' },
                          persister: Valkyrie::MetadataAdapter.find(:indexing_persister).persister)
    end

    it 'will be invalid' do
      expect(form).not_to be_valid
    end
  end
end
