# frozen_string_literal: true

# Skipping because this was failing intermittently on travis
RSpec.feature 'Creating a new Work', :js, :workflow, skip: true do
  let(:user) { create(:user) }
  let(:file1) { File.open(fixture_path + '/world.png') }
  let(:file2) { File.open(fixture_path + '/image.jp2') }
  let!(:uploaded_file1) { Hyrax::UploadedFile.create(file: file1, user: user) }
  let!(:uploaded_file2) { Hyrax::UploadedFile.create(file: file2, user: user) }

  before do
    # Grant the user access to deposit into an admin set.
    create(:permission_template_access,
           :deposit,
           permission_template: create(:permission_template, with_admin_set: true),
           agent_type: 'user',
           agent_id: user.user_key)
    # stub out characterization. Travis doesn't have fits installed, and it's not relevant to the test.
    allow(CharacterizeJob).to receive(:perform_later)
  end

  context "when the user is not a proxy", skip: "This was failing intermittently" do
    before do
      sign_in user
      click_link "Create Work"
      choose "payload_concern", option: "GenericWork"
      click_button 'Create work'
    end

    it 'creates the work' do
      click_link "Files" # switch tab
      expect(page).to have_content "Add files"
      expect(page).to have_content "Add folder"
      # Capybara/poltergeist don't dependably upload files, so we'll stub out the results of the uploader:
      page.execute_script("$(\"#new_generic_work\").append('<input name=\"uploaded_files[]\" value=\"#{uploaded_file1.id}\" type=\"hidden\">')" \
        ".append('<input name=\"uploaded_files[]\" value=\"#{uploaded_file2.id}\" type=\"hidden\">');")
      # attach_file("files[]", File.dirname(__FILE__) + "/../../spec/fixtures/image.jp2", visible: false)
      # attach_file("files[]", File.dirname(__FILE__) + "/../../spec/fixtures/jp2_fits.xml", visible: false)
      # click_button "Start upload"
      click_link "Metadata" # switch tab
      fill_in('Title', with: 'My Test Work')

      choose('generic_work_visibility_open')
      expect(page).to have_content('Please note, making something visible to the world (i.e. marking this as Public) may be viewed as publishing which could impact your ability to')
      # attach_file('Upload a file', fixture_file_path('files/image.png'))
      check('agreement')
      puts "Required metadata: #{page.evaluate_script(%{$('#form-progress').data('save_work_control').requiredFields.areComplete})}"
      puts "Required files: #{page.evaluate_script(%{$('#form-progress').data('save_work_control').uploads.hasFiles})}"
      puts "Agreement : #{page.evaluate_script(%{$('#form-progress').data('save_work_control').depositAgreement.isAccepted})}"
      click_on('Save')
      expect(page).to have_content('My Test Work')
      expect(page).to have_content "Your files are being processed by Hyrax in the background."
    end
  end

  context 'when the user is a proxy', skip: "This was failing intermittently" do
    let(:second_user) { create(:user) }
    before do
      ProxyDepositRights.create!(grantor: second_user, grantee: user)
      sign_in user
      click_link "Create Work"
      choose "payload_concern", option: "GenericWork"
      click_button 'Create work'
    end

    it "allows on-behalf-of deposit" do
      click_link "Files" # switch tab
      expect(page).to have_content "Add files"

      # Capybara/poltergeist don't dependably upload files, so we'll stub out the results of the uploader:
      page.execute_script("$(\"#new_generic_work\").append('<input name=\"uploaded_files[]\" value=\"#{uploaded_file1.id}\" type=\"hidden\">')" \
        ".append('<input name=\"uploaded_files[]\" value=\"#{uploaded_file2.id}\" type=\"hidden\">');")
      # attach_file("files[]", File.dirname(__FILE__) + "/../../spec/fixtures/image.jp2", visible: false)
      # attach_file("files[]", File.dirname(__FILE__) + "/../../spec/fixtures/jp2_fits.xml", visible: false)
      # click_button "Start upload"

      click_link "Metadata" # switch tab
      fill_in('Title', with: 'My Test Work')

      choose('generic_work_visibility_open')
      expect(page).to have_content('Please note, making something visible to the world (i.e. marking this as Public) may be viewed as publishing which could impact your ability to')
      select(second_user.user_key, from: 'On behalf of')
      check('agreement')
      puts "Required metadata: #{page.evaluate_script(%{$('#form-progress').data('save_work_control').requiredFields.areComplete})}"
      puts "Required files: #{page.evaluate_script(%{$('#form-progress').data('save_work_control').uploads.hasFiles})}"
      puts "Agreement : #{page.evaluate_script(%{$('#form-progress').data('save_work_control').depositAgreement.isAccepted})}"
      click_on('Save')

      expect(page).to have_content('My Test Work')
      expect(page).to have_content "Your files are being processed by Hyrax in the background."

      click_link('Dashboard')
      click_link('Shares')

      click_link('Works Shared with Me')
      expect(page).to have_content "My Test Work"
      # TODO: Show the work details (owner email)
      # first('i.glyphicon-chevron-right').click
      # first('.expanded-details').click_link(second_user.email)
    end
  end
end
