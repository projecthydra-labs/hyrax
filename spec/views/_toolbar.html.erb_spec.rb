describe '/_toolbar.html.erb', type: :view do
  let(:presenter) { instance_double(Hyrax::SelectTypeListPresenter, many?: false, first_model: GenericWork) }
  let(:user) { stub_model(User, user_key: 'userX') }
  before do
    allow(view).to receive(:create_work_presenter).and_return(presenter)
    allow(view).to receive(:user_signed_in?).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow(view).to receive(:can?).and_call_original
  end

  context 'with an anonymous user' do
    before do
      allow(view).to receive(:user_signed_in?).and_return(false)
    end

    it 'shows no toolbar links' do
      render
      expect(rendered).not_to have_link 'Admin'
      expect(rendered).not_to have_link 'Dashboard'
      expect(rendered).not_to have_link 'Works'
      expect(rendered).not_to have_link 'Collections'
    end
  end

  context 'with an admin user' do
    before do
      allow(view).to receive(:can?).with(:read, :admin_dashboard).and_return(true)
    end

    it 'shows the admin menu' do
      render
      expect(rendered).to have_link 'Admin', href: hyrax.admin_path
    end
  end

  it 'has dashboard links' do
    render
    expect(rendered).to have_link 'My Dashboard', href: hyrax.dashboard_index_path
    expect(rendered).to have_link 'Operations', href: hyrax.user_operations_path(user)
    expect(rendered).to have_link 'Transfers', href: hyrax.transfers_path
    expect(rendered).to have_link 'Highlights', href: hyrax.dashboard_highlights_path
    expect(rendered).to have_link 'Shares', href: hyrax.dashboard_shares_path
  end

  describe "New Work link" do
    before do
      allow(view.current_ability).to receive(:can_create_any_work?).and_return(can_create)
    end
    let(:can_create) { true }

    context "when the user can create multiple work types" do
      let(:presenter) { instance_double(Hyrax::SelectTypeListPresenter, many?: true) }
      it "has a link to upload" do
        render
        expect(rendered).to have_selector 'a[data-behavior="select-work"][data-target="#worktypes-to-create"][data-create-type="single"]'
        expect(rendered).to have_link('New Work', href: '#')

        expect(rendered).to have_selector 'a[data-behavior="select-work"][data-target="#worktypes-to-create"][data-create-type="batch"]'
        expect(rendered).to have_link('Batch Create', href: '#')
      end
    end

    context "when the user can create a single work type" do
      let(:presenter) { instance_double(Hyrax::SelectTypeListPresenter, many?: false, first_model: GenericWork) }
      it "has a link to upload" do
        render
        expect(rendered).to have_link('New Work', href: new_hyrax_generic_work_path)
        expect(rendered).to have_link('Batch Create', href: hyrax.new_batch_upload_path(payload_concern: 'GenericWork'))
      end
    end

    context "when the user can't create any work types" do
      let(:can_create) { false }
      it "does not have a link to upload" do
        render
        expect(rendered).not_to have_link('New Work')
      end
    end
  end

  describe "New Collection link" do
    context "when the user can create collections" do
      it "has a link to upload" do
        allow(view).to receive(:can?).with(:create, Collection).and_return(true)
        render
        expect(rendered).to have_link('New Collection', href: hyrax.new_collection_path)
      end
    end

    context "when the user can't create file sets" do
      it "does not have a link to upload" do
        allow(view).to receive(:can?).with(:create, Collection).and_return(false)
        render
        expect(rendered).not_to have_link('New Collection')
      end
    end
  end
end
