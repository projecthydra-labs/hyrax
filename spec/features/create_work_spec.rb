# Skipping because this was failing intermittently on travis
RSpec.feature 'Creating a new Work', :js, :workflow do
  let(:user) { create(:user) }
  let(:file1) { File.open(fixture_path + '/world.png') }
  let(:file2) { File.open(fixture_path + '/image.jp2') }
  let!(:uploaded_file1) { Hyrax::UploadedFile.create(file: file1, user: user) }
  let!(:uploaded_file2) { Hyrax::UploadedFile.create(file: file2, user: user) }

  before do
    # Grant the user access to deposit into an admin set.
    create(:permission_template_access,
           :deposit,
           permission_template: create(:permission_template, with_admin_set: true, with_workflows: true),
           agent_type: 'user',
           agent_id: user.user_key)
    # stub out characterization. Travis doesn't have fits installed, and it's not relevant to the test.
    allow(CharacterizeJob).to receive(:perform_later)
  end

  context "when the user is not a proxy" do
    before { sign_in user }

    it 'creates a single generic work' do
      visit new_hyrax_generic_work_path
      # click_link "Share Your Work"
      # choose "payload_concern", option: "GenericWork"
      # click_button 'Create work'
      expect(page).to have_content 'Add New Work'
      click_link "Files" # switch tab
      expect(page).to have_content "Add files"
      # expect(page).to have_content "Add folder"
      # Capybara/poltergeist don't dependably upload files, so we'll stub out the results of the uploader:
      page.execute_script("$(\"#new_generic_work\").append('<input name=\"uploaded_files[]\" value=\"#{uploaded_file1.id}\" type=\"hidden\">')" \
        ".append('<input name=\"uploaded_files[]\" value=\"#{uploaded_file2.id}\" type=\"hidden\">');")
      # attach_file("files[]", File.dirname(__FILE__) + "/../../spec/fixtures/image.jp2", visible: false)
      # attach_file("files[]", File.dirname(__FILE__) + "/../../spec/fixtures/jp2_fits.xml", visible: false)
      # click_button "Start upload"
      click_link "Descriptions" # switch tab
      fill_in('Title', with: 'My Test Work')
      fill_in('Creator', with: 'Jane Doe')
      fill_in('Keyword', with: 'Testing is fun!')
      select('No Known Copyright', from: 'generic_work_rights_statement')

      choose('generic_work_visibility_open')
      expect(page).to have_content('Please note, making something visible to the world (i.e. marking this as Open Access) may be viewed as publishing which could impact your ability to')
      # attach_file('Upload a file', fixture_file_path('files/image.png'))
      check('agreement')
      puts "Required metadata: #{page.evaluate_script(%{$('#form-progress').data('save_work_control').requiredFields.areComplete})}"
      puts "Required files: #{page.evaluate_script(%{$('#form-progress').data('save_work_control').uploads.hasFiles})}"
      puts "Agreement : #{page.evaluate_script(%{$('#form-progress').data('save_work_control').depositAgreement.isAccepted})}"
      click_on('Save')
      expect(page).to have_content('My Test Work')
      expect(page).to have_content "Your files are being processed by Hyrax in the background."
    end

    it 'creates a batch of generic works' do
      visit hyrax.new_batch_upload_path(payload_concern: 'GenericWork')
      # click_link "Share Your Work"
      # choose "payload_concern", option: "GenericWork"
      # click_button 'Create work'
      expect(page).to have_content 'Add New Works by Batch'
      click_link "Files" # switch tab
      expect(page).to have_content "Add files"
      # expect(page).to have_content "Add folder"
      # Capybara/poltergeist don't dependably upload files, so we'll stub out the results of the uploader:
      page.execute_script("$(\"#new_batch_upload_item\").append('<input name=\"uploaded_files[]\" value=\"#{uploaded_file1.id}\" type=\"hidden\">')" \
        ".append('<input name=\"uploaded_files[]\" value=\"#{uploaded_file2.id}\" type=\"hidden\">');")
      # attach_file("files[]", File.dirname(__FILE__) + "/../../spec/fixtures/image.jp2", visible: false)
      # attach_file("files[]", File.dirname(__FILE__) + "/../../spec/fixtures/jp2_fits.xml", visible: false)
      # click_button "Start upload"
      click_link "Descriptions" # switch tab
      fill_in('Creator', with: 'Jane Doe')
      fill_in('Keyword', with: 'Testing is fun!')
      select('No Known Copyright', from: 'batch_upload_item_rights_statement')

      choose('batch_upload_item_visibility_open')
      # TODO: Figure out why the open access warning isn't appearing in the batch context
      expect(page).to have_content('Everyone. Check out SHERPA/RoMEO for specific publishers\' copyright policies if you plan to patent and/or publish your Works by Batch in a journa')
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
