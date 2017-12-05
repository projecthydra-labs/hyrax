require "spec_helper"

RSpec.describe "hyrax/admin/admin_sets/index.html.erb", type: :view do
  before do
    allow(controller).to receive(:can?).with(:create, AdminSet).and_return(false)
  end

  context "when no admin sets exists" do
    it "alerts users there are no admin sets" do
      render
      expect(rendered).to have_content("No administrative sets have been created.")
    end
  end

  context "when an admin set exists" do
    let(:document) { Valkyrie::MetadataAdapter.find(:index_solr).resource_factory.from_resource(resource: admin_set) }
    let(:solr_doc) { SolrDocument.new(document) }
    let(:admin_set) { create_for_repository(:admin_set, id: '123', title: ['Example Admin Set'], creator: ['jdoe@example.com']) }
    let(:admin_sets) { [solr_doc] }
    let(:presenter_class) { Hyrax::AdminSetPresenter }
    let(:presenter) { instance_double(presenter_class, total_items: 99) }
    let(:ability) { instance_double("Ability") }

    before do
      allow(controller).to receive(:current_ability).and_return(ability)
      allow(controller).to receive(:presenter_class).and_return(presenter_class)
      allow(presenter_class).to receive(:new).and_return(presenter)
      assign(:admin_sets, admin_sets)
    end
    it "lists admin set" do
      render
      expect(rendered).to have_content('Example Admin Set')
      expect(rendered).to have_content('jdoe@example.com')
      expect(rendered).to have_css("td", text: /^99$/)
    end
  end
end
