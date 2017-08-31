RSpec.feature 'embargo' do
  let(:user) { create(:user) }

  before do
    sign_in user
  end
  describe 'creating an embargoed object' do
    let(:future_date) { 5.days.from_now }
    let(:later_future_date) { 10.days.from_now }

    it 'can be created, displayed and updated', :clean_repo, :workflow do
      visit '/concern/generic_works/new'
      fill_in 'Title', with: 'Embargo test'
      choose 'Embargo'
      fill_in 'generic_work_embargo_release_date', with: future_date
      select 'Private', from: 'Restricted to'
      select 'Public', from: 'then open it up to'
      click_button 'Save'

      # chosen embargo date is on the show page
      page.assert_text(future_date.to_date.to_formatted_s(:standard))

      click_link 'Edit'
      click_link 'Embargo Management Page'

      page.assert_text('This Generic Work is under embargo.')
      expect(page).to have_xpath("//input[@name='generic_work[embargo_release_date]' and @value='#{future_date.to_datetime.iso8601}']") # current embargo date is pre-populated in edit field

      fill_in 'until', with: later_future_date.to_s

      click_button 'Update Embargo'
      page.assert_text(later_future_date.to_date.to_formatted_s(:standard))
    end
  end
end
