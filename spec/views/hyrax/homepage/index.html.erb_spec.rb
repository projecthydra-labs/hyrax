# frozen_string_literal: true

RSpec.describe "hyrax/homepage/index.html.erb", type: :view do
  let(:groups) { [] }
  let(:ability) { instance_double("Ability", can?: false) }
  let(:presenter) { Hyrax::HomepagePresenter.new(ability) }

  describe "share your work button" do
    before do
      allow(view).to receive(:signed_in?).and_return(signed_in)
      assign(:presenter, presenter)
      allow(controller).to receive(:current_ability).and_return(ability)
      allow(presenter).to receive(:display_share_button?).and_return(display_share_button)
      stub_template "hyrax/homepage/_marketing.html.erb" => "marketing"
      stub_template "hyrax/homepage/_home_content.html.erb" => "home content"
      render
    end

    context "when not signed in" do
      let(:signed_in) { false }
      context "when the button always displays" do
        let(:display_share_button) { true }
        it "displays" do
          expect(rendered).to have_content t("hyrax.share_button")
        end
      end
      context "when the button displays for users with rights" do
        let(:display_share_button) { false }
        it "does not display" do
          expect(rendered).not_to have_content t("hyrax.share_button")
        end
      end
    end

    context "when signed in" do
      let(:signed_in) { true }
      context "when the button always displays" do
        let(:display_share_button) { true }
        it "displays" do
          expect(rendered).to have_content t("hyrax.share_button")
        end
      end
      context "when the button displays for users with rights" do
        let(:display_share_button) { false }
        it "does not display" do
          expect(rendered).not_to have_content t("hyrax.share_button")
        end
      end
    end
  end
end
