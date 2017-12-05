RSpec.describe 'hyrax/base/_form_relationships.html.erb', type: :view do
  let(:work) { GenericWork.new }
  let(:change_set) do
    GenericWorkChangeSet.new(work)
  end
  let(:service) { instance_double Hyrax::AdminSetService }
  let(:presenter) { instance_double Hyrax::AdminSetOptionsPresenter, select_options: [] }
  let(:form_template) do
    %(
      <%= simple_form_for @change_set do |f| %>
        <%= render "hyrax/base/form_relationships", f: f %>
      <% end %>
    )
  end

  let(:page) do
    assign(:change_set, change_set)
    render inline: form_template
    Capybara::Node::Simple.new(rendered)
  end

  before do
    allow(view).to receive(:action_name).and_return('new')
    allow(Hyrax::AdminSetService).to receive(:new).with(controller).and_return(service)
    allow(Hyrax::AdminSetOptionsPresenter).to receive(:new).with(service).and_return(presenter)
  end

  context 'with assign_admin_set turned on' do
    before do
      allow(Flipflop).to receive(:assign_admin_set?).and_return(true)
    end

    it "draws the page" do
      expect(page).to have_content('Administrative Set')
      expect(page).to have_selector('select#generic_work_admin_set_id')
    end
  end

  context 'with assign_admin_set disabled' do
    before do
      allow(Flipflop).to receive(:assign_admin_set?).and_return(false)
    end
    it 'draws the page, but not the admin set widget' do
      expect(page).not_to have_content('administrative set')
    end
  end
end
