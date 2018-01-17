RSpec.describe Hyrax::LeasesController do
  let(:user) { create(:user) }
  let(:not_my_work) { create_for_repository(:work) }

  before { sign_in user }

  describe '#index' do
    context 'when I am NOT a repository manager' do
      it 'redirects' do
        get :index
        expect(response).to redirect_to root_path
      end
    end
    context 'when I am a repository manager' do
      let(:user) { create(:user, groups: ['admin']) }

      it 'shows me the page' do
        get :index
        expect(response).to be_success
      end
    end
  end

  describe '#edit' do
    context 'when I do not have edit permissions for the object' do
      it 'redirects' do
        get :edit, params: { id: not_my_work }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end
    context 'when I have permission to edit the object' do
      let(:a_work) { create_for_repository(:leased_work, user: user) }

      it 'shows me the page' do
        get :edit, params: { id: a_work }
        expect(response).to be_success
      end
    end
  end

  describe '#destroy' do
    context 'when I do not have edit permissions for the object' do
      it 'denies access' do
        get :destroy, params: { id: not_my_work }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq 'You are not authorized to access this page.'
      end
    end

    context 'when I have permission to edit the object' do
      let(:actor) { double('lease actor') }
      let(:lease) { instance_double(Hyrax::Lease, lease_history: ['it gone']) }

      before do
        allow(Hyrax::Actors::LeaseActor).to receive(:new).with(GenericWork).and_return(actor)
      end

      context 'that has no files' do
        let(:a_work) { create_for_repository(:work, user: user) }

        it 'deactivates the lease and redirects' do
          expect(actor).to receive(:destroy).and_return(lease)
          get :destroy, params: { id: a_work }
          expect(response).to redirect_to edit_lease_path(a_work)
        end
      end

      context 'with files' do
        let(:a_work) { create_for_repository(:work_with_one_file, user: user) }

        it 'deactivates the lease and redirects' do
          expect(actor).to receive(:destroy).and_return(lease)
          get :destroy, params: { id: a_work }
          expect(response).to redirect_to confirm_permission_path(a_work)
        end
      end
    end
  end

  describe '#update' do
    context 'when I have permission to edit the object' do
      let(:file_set) { create_for_repository(:file_set, visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC) }
      let(:lease) do
        create_for_repository(:lease,
                              visibility_during_lease: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC,
                              visibility_after_lease: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED,
                              lease_expiration_date: [expiration_date])
      end
      let(:a_work) do
        create_for_repository(:work,
                              user: user,
                              member_ids: [file_set.id],
                              visibility: Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED,
                              lease_id: lease.id)
      end

      context 'with an expired lease' do
        let(:expiration_date) { 2.days.ago }
        let(:reloaded_work) { Hyrax::Queries.find_by(id: a_work.id) }
        let(:reloaded_file_set) { Hyrax::Queries.find_by(id: file_set.id) }

        it 'deactivates lease, update the visibility and redirect' do
          patch :update, params: { batch_document_ids: [a_work.id], leases: { '0' => { copy_visibility: a_work.id } } }
          expect(reloaded_work.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
          expect(reloaded_file_set.visibility).to eq Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
          expect(response).to redirect_to leases_path
        end
      end
    end
  end
end
