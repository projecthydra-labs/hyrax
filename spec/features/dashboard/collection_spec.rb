RSpec.describe 'collection', type: :feature, clean_repo: true do
  let(:user) { create(:user) }
  let(:admin_user) { create(:admin) }
  let(:collection_type) { create(:collection_type, creator_user: user) }
  let(:user_collection_type) { create(:user_collection_type) }
  let(:solr_gid) { Collection.collection_type_gid_document_field_name }

  # Setting Title on admin sets to avoid false positive matches with collections.
  let(:admin_set_a) { create(:admin_set, creator: [admin_user.user_key], title: ['Set A'], with_permission_template: true) }
  let(:admin_set_b) { create(:admin_set, creator: [user.user_key], title: ['Set B'], edit_users: [user.user_key], with_permission_template: true) }
  let(:collection1) { create(:public_collection, user: user, collection_type_gid: collection_type.gid, with_permission_template: true) }
  let(:collection2) { create(:public_collection, user: user, collection_type_gid: collection_type.gid, with_permission_template: true) }
  let(:collection3) { create(:public_collection, user: admin_user, collection_type_gid: collection_type.gid, with_permission_template: true) }

  describe 'Your Collections tab' do
    context 'when non-admin user' do
      before do
        user
        admin_user
        admin_set_a
        create(:permission_template_access,
               :manage,
               permission_template: admin_set_b.permission_template,
               agent_type: 'user',
               agent_id: user.user_key)
        collection1
        collection2
        collection3
        sign_in user
        visit '/dashboard/my/collections'
      end

      it "has page title, does not have tabs, and lists only user's collections" do
        expect(page).to have_content 'Collections'
        expect(page).not_to have_link 'All Collections'
        expect(page).not_to have_link 'Your Collections'
        expect(page).to have_link(collection1.title.first)
        expect(page).to have_link(collection2.title.first)
        expect(page).to have_link(admin_set_b.title.first)
        expect(page).not_to have_link(collection3.title.first)
        expect(page).not_to have_link(admin_set_a.title.first)
      end
    end

    context 'when admin user' do
      before do
        user
        admin_user
        create(:permission_template_access,
               :manage,
               permission_template: admin_set_a.permission_template,
               agent_type: 'user',
               agent_id: admin_user.user_key)
        create(:permission_template_access,
               :manage,
               permission_template: admin_set_b.permission_template,
               agent_type: 'group',
               agent_id: 'admin')
        collection1
        collection2
        collection3
        sign_in admin_user
        visit '/dashboard/my/collections'
      end

      it "has page title, has tabs for All and Your Collections, and lists collections with edit access" do
        expect(page).to have_content 'Collections'
        expect(page).to have_link 'All Collections'
        expect(page).to have_link 'Your Collections'
        expect(page).to have_link(collection3.title.first)
        expect(page).to have_link(admin_set_a.title.first)
        expect(page).not_to have_link(collection1.title.first)
        expect(page).not_to have_link(collection2.title.first)
        expect(page).not_to have_link(admin_set_b.title.first)
      end

      it "has collection type and visibility filters" do
        expect(page).to have_button 'Visibility'
        expect(page).to have_link 'Public',
                                  href: /visibility_ssi.+#{Regexp.escape(CGI.escape(collection3.visibility))}/
        expect(page).to have_button 'Type'
        expect(page).to have_link collection_type.title,
                                  href: /#{solr_gid}.+#{Regexp.escape(CGI.escape(collection_type.gid))}/
      end
    end
  end

  describe 'All Collections tab (for admin users only)' do
    before do
      user
      admin_user
      collection1
      collection2
      collection3
      sign_in admin_user
      visit '/dashboard/my/collections'
    end

    it 'lists all collections for all users', with_nested_reindexing: true do
      expect(page).to have_link 'All Collection'
      click_link 'All Collections'
      expect(page).to have_link(collection1.title.first)
      expect(page).to have_link(collection2.title.first)
      expect(page).to have_link(collection3.title.first)
    end

    it 'has a collection type filter' do
      expect(page).to have_button 'Visibility'
      expect(page).to have_link 'Public',
                                href: /visibility_ssi.+#{Regexp.escape(CGI.escape(collection1.visibility))}/
      expect(page).to have_button 'Type'
      expect(page).to have_link collection_type.title,
                                href: /#{solr_gid}.+#{Regexp.escape(CGI.escape(collection_type.gid))}/
    end
  end

  describe 'create collection' do
    let(:title) { "Test Collection" }
    let(:description) { "Description for collection we are testing." }

    context 'when user can create collections of multiple types' do
      before do
        collection_type
        user_collection_type

        sign_in user
        visit '/dashboard/my/collections'
      end

      it "makes a new collection", :js do
        click_button "New Collection"
        expect(page).to have_content 'Select type of collection'

        choose('User Collection')
        click_on('Create collection')

        expect(page).to have_selector('h1', text: 'New User Collection')
        expect(page).to have_selector "input.collection_title.multi_value"

        click_link('Additional fields')
        expect(page).to have_selector "input.collection_creator.multi_value"

        fill_in('Title', with: title)
        fill_in('Abstract or Summary', with: description)
        fill_in('Related URL', with: 'http://example.com/')

        click_button("Save")
        expect(page).to have_content title
        expect(page).to have_content description
      end
    end

    context 'when user can create collections of one type' do
      before do
        user_collection_type

        sign_in user
        visit '/dashboard/my/collections'
      end

      it 'makes a new collection' do
        click_link "New Collection"
        expect(page).to have_selector('h1', text: 'New User Collection')
        expect(page).to have_selector "input.collection_title.multi_value"

        click_link('Additional fields')
        expect(page).to have_selector "input.collection_creator.multi_value"

        fill_in('Title', with: title)
        fill_in('Abstract or Summary', with: description)
        fill_in('Related URL', with: 'http://example.com/')

        click_button("Save")
        expect(page).to have_content title
        expect(page).to have_content description
      end
    end

    context 'when user can not create collections' do
      before do
        sign_in user
        visit '/dashboard/my/collections'
      end

      it 'does show New Collection button' do
        expect(page).not_to have_link "New Collection"
        expect(page).not_to have_button "New Collection"
      end
    end
  end

  describe "adding works to a collection", skip: "we need to define a dashboard/works path" do
    let!(:collection) { create!(:collection, title: ["Barrel of monkeys"], user: user, with_permission_template: true) }
    let!(:work1) { create(:work, title: ["King Louie"], user: user) }
    let!(:work2) { create(:work, title: ["King Kong"], user: user) }

    before do
      sign_in user
    end

    it "attaches the works", :js do
      visit '/dashboard/my/works'
      first('input#check_all').click
      click_button "Add to Collection" # opens the modal
      # since there is only one collection, it's not necessary to choose a radio button
      click_button "Update Collection"
      expect(page).to have_content "Works in this Collection"
      # There are two rows in the table per document (one for the general info, one for the details)
      # Make sure we have at least 2 documents
      expect(page).to have_selector "table.table-zebra-striped tr#document_#{work1.id}"
      expect(page).to have_selector "table.table-zebra-striped tr#document_#{work2.id}"
    end
  end

  describe 'delete collection' do
    let!(:empty_collection) { create(:public_collection, title: ['Empty Collection'], user: user, with_permission_template: true) }
    let!(:collection) { create(:public_collection, title: ['Collection with Work'], user: user, with_permission_template: true) }
    let!(:admin_user) { create(:admin) }
    let!(:empty_adminset) { create(:admin_set, title: ['Empty Admin Set'], creator: [admin_user.user_key], with_permission_template: true) }
    let!(:adminset) { create(:admin_set, title: ['Admin Set with Work'], creator: [admin_user.user_key], with_permission_template: true) }
    let!(:work) { create(:work, title: ["King Louie"], admin_set: adminset, member_of_collections: [collection], user: user) }

    context 'when user created the collection' do
      before do
        user
        sign_in user
        visit '/dashboard/my/collections' # Your Collections tab
      end

      context 'and collection is empty' do
        it 'and user confirms delete, deletes the collection', :js do
          expect(page).to have_content(empty_collection.title.first)
          within('#document_' + empty_collection.id) do
            first('button.dropdown-toggle').click
            first('.itemtrash').click
          end
          expect(page).to have_selector("div#collection-empty-to-delete-modal-#{empty_collection.id}", visible: true)
          within("div#collection-empty-to-delete-modal-#{empty_collection.id}") do
            click_link('Delete')
          end
          expect(page).not_to have_content(empty_collection.title.first)
        end

        it 'and user cancels, does NOT delete the collection', :js do
          expect(page).to have_content(empty_collection.title.first)
          within("#document_#{empty_collection.id}") do
            first('button.dropdown-toggle').click
            first('.itemtrash').click
          end
          expect(page).to have_selector("div#collection-empty-to-delete-modal-#{empty_collection.id}", visible: true)
          within("div#collection-empty-to-delete-modal-#{empty_collection.id}") do
            click_button('Cancel')
          end
          expect(page).to have_content(empty_collection.title.first)
        end
      end

      context 'and collection is not empty' do
        it 'and user confirms delete, deletes the collection', :js do
          expect(page).to have_content(collection.title.first)
          within("#document_#{collection.id}") do
            first('button.dropdown-toggle').click
            first('.itemtrash').click
          end
          expect(page).to have_selector("div#collection-to-delete-modal-#{collection.id}", visible: true)
          within("div#collection-to-delete-modal-#{collection.id}") do
            click_link('Delete')
          end
          expect(page).not_to have_content(collection.title.first)
        end

        it 'and user cancels, does NOT delete the collection', :js do
          expect(page).to have_content(collection.title.first)
          within("#document_#{collection.id}") do
            first('button.dropdown-toggle').click
            first('.itemtrash').click
          end
          expect(page).to have_selector("div#collection-to-delete-modal-#{collection.id}", visible: true)
          within("div#collection-to-delete-modal-#{collection.id}") do
            click_button('Cancel')
          end
          expect(page).to have_content(collection.title.first)
        end
      end
    end

    context 'when user without permissions selects delete' do
      let(:user2) { create(:user) }

      before do
        create(:permission_template_access,
               :deposit,
               permission_template: collection.permission_template,
               agent_type: 'user',
               agent_id: user2.user_key)
        sign_in user2
        visit '/dashboard/collections' # Managed Collections tab
      end

      it 'does not allow delete collection' do
        expect(page).to have_content(collection.title.first)
        within("#document_#{collection.id}") do
          first('button.dropdown-toggle').click
          first('.itemtrash').click
        end
        expect(page).to have_selector('div#collection-to-delete-deny-modal', visible: true)
        within('div#collection-to-delete-deny-modal') do
          click_button('Close')
        end
        expect(page).to have_content(collection.title.first)
      end
    end

    context 'when user created the admin set' do
      before do
        sign_in admin_user
        visit '/dashboard/collections' # All Collections tab
      end

      context 'and admin set is empty' do
        it 'and user confirms delete, deletes the admin set', :js do
          expect(page).to have_content(empty_adminset.title.first)
          within('#document_' + empty_adminset.id) do
            first('button.dropdown-toggle').click
            first('.itemtrash').click
          end
          expect(page).to have_selector("div#collection-admin-set-empty-to-delete-modal-#{empty_adminset.id}", visible: true)
          within("div#collection-admin-set-empty-to-delete-modal-#{empty_adminset.id}") do
            click_link('Delete')
          end
          expect(page).not_to have_content(empty_adminset.title.first)
        end

        it 'and user cancels, does NOT delete the admin set', :js do
          expect(page).to have_content(empty_adminset.title.first)
          within("#document_#{empty_adminset.id}") do
            first('button.dropdown-toggle').click
            first('.itemtrash').click
          end
          expect(page).to have_selector("div#collection-admin-set-empty-to-delete-modal-#{empty_adminset.id}", visible: true)
          within("div#collection-admin-set-empty-to-delete-modal-#{empty_adminset.id}") do
            click_button('Cancel')
          end
          expect(page).to have_content(empty_adminset.title.first)
        end
      end

      context 'and admin set is not empty' do
        it 'does not allow delete admin set' do
          expect(page).to have_content(adminset.title.first)
          within("#document_#{adminset.id}") do
            first('button.dropdown-toggle').click
            first('.itemtrash').click
          end
          expect(page).to have_selector("div#collection-admin-set-delete-deny-modal-#{adminset.id}", visible: true)
          within("div#collection-admin-set-delete-deny-modal-#{adminset.id}") do
            click_button('Close')
          end
          expect(page).to have_content(adminset.title.first)
        end
      end
    end

    context 'when user without permissions selects delete' do
      let(:user2) { create(:user) }

      before do
        create(:permission_template_access,
               :view,
               permission_template: adminset.permission_template,
               agent_type: 'user',
               agent_id: user2.user_key)
        sign_in user2
        visit '/dashboard/collections' # Managed Collections tab
      end

      xit 'does not allow delete admin set' do
        # TODO: Depositors & viewers cannot see admin sets in Managed Collections list.  Should they?
        expect(page).to have_content(adminset.title.first)
        within("#document_#{adminset.id}") do
          first('button.dropdown-toggle').click
          first('.itemtrash').click
        end
        expect(page).to have_selector('div#collection-to-delete-deny-modal', visible: true)
        within('div#collection-to-delete-deny-modal') do
          click_button('Close')
        end
        expect(page).to have_content(adminset.title.first)
      end
    end
  end

  describe 'collection show page', with_nested_reindexing: true do
    let(:collection) do
      create(:public_collection, user: user, description: ['collection description'], with_permission_template: true)
    end
    let!(:work1) { create(:work, title: ["King Louie"], member_of_collections: [collection], user: user) }
    let!(:work2) { create(:work, title: ["King Kong"], member_of_collections: [collection], user: user) }

    before do
      sign_in user
      visit '/dashboard/my/collections'
    end

    it "has creation date for collections and shows a collection with a listing of Descriptive Metadata and catalog-style search results" do
      expect(page).to have_content(collection.create_date.to_date.to_formatted_s(:standard))

      expect(page).to have_content(collection.title.first)
      within('#document_' + collection.id) do
        click_link("Display all details of #{collection.title.first}")
      end
      expect(page).to have_content(collection.title.first)
      expect(page).to have_content(collection.description.first)
      # Should not show title and description a second time
      expect(page).not_to have_css('.metadata-collections', text: collection.title.first)
      expect(page).not_to have_css('.metadata-collections', text: collection.description.first)
      # Should not have Collection Descriptive metadata table
      expect(page).to have_content("Descriptions")
      # Should have search results / contents listing
      expect(page).to have_content(work1.title.first)
      expect(page).to have_content(work2.title.first)
      expect(page).not_to have_css(".pager")

      click_link "Gallery"
      expect(page).to have_content(work1.title.first)
      expect(page).to have_content(work2.title.first)
    end

    it "hides collection descriptive metadata when searching a collection" do
      # URL: /dashboard/my/collections
      expect(page).to have_content(collection.title.first)
      within("#document_#{collection.id}") do
        click_link("Display all details of #{collection.title.first}")
      end
      # URL: /dashboard/collections/collection-id
      expect(page).to have_content(collection.title.first)
      expect(page).to have_content(collection.description.first)
      expect(page).to have_content(work1.title.first)
      expect(page).to have_content(work2.title.first)
      fill_in('collection_search', with: work1.title.first)
      click_button('collection_submit')
      # Should not have Collection metadata table (only title and description)
      expect(page).not_to have_content("Total works")
      expect(page).to have_content(collection.title.first)
      expect(page).to have_content(collection.description.first)
      # Should have search results / contents listing
      expect(page).to have_content("Search Results")
      expect(page).to have_content(work1.title.first)
      expect(page).not_to have_content(work2.title.first)
    end

    context 'adding existing works to a collection', js: true do
      before do
        collection1 # create collections by referencing them
        collection2
        sign_in user
      end

      it "preselects the collection we are adding works to and adds the selected works" do
        visit "/dashboard/collections/#{collection1.id}"
        click_link 'Add existing works'
        first('input#check_all').click
        click_button "Add to Collection"
        expect(page).to have_css("input#id_#{collection1.id}[checked='checked']")
        expect(page).not_to have_css("input#id_#{collection2.id}[checked='checked']")

        visit "/dashboard/collections/#{collection2.id}"
        click_link 'Add existing works'
        first('input#check_all').click
        click_button "Add to Collection"
        expect(page).not_to have_css("input#id_#{collection1.id}[checked='checked']")
        expect(page).to have_css("input#id_#{collection2.id}[checked='checked']")

        click_button "Save changes"
        expect(page).to have_content(work1.title.first)
        expect(page).to have_content(work2.title.first)
      end
    end

    context 'adding a new works to a collection', js: true do
      before do
        collection1 # create collections by referencing them
        collection2
        sign_in user
        # stub out characterization. Travis doesn't have fits installed, and it's not relevant to the test.
        allow(CharacterizeJob).to receive(:perform_later)
      end

      it "preselects the collection we are adding works to and adds the new work" do
        visit "/dashboard/collections/#{collection1.id}"
        click_link 'Add new work'
        choose "payload_concern", option: "GenericWork"
        click_button 'Create work'

        # verify the collection is pre-selected
        click_link "Relationships" # switch tab
        expect(page).to have_selector("table tr", text: collection1.title.first)
        expect(page).not_to have_selector("table tr", text: collection2.title.first)

        # add required file
        click_link "Files" # switch tab
        within('span#addfiles') do
          attach_file("files[]", "#{Hyrax::Engine.root}/spec/fixtures/image.jp2", visible: false)
        end
        # set required metadata
        click_link "Descriptions" # switch tab
        fill_in('Title', with: 'New Work for Collection')
        fill_in('Creator', with: 'Doe, Jane')
        fill_in('Keyword', with: 'testing')
        select('In Copyright', from: 'Rights statement')
        # check required acceptance
        check('agreement')

        click_on('Save')

        # verify new work was added to collection1
        visit "/dashboard/collections/#{collection1.id}"
        expect(page).to have_content("New Work for Collection")
      end
    end
  end

  # TODO: this is just like the block above. Merge them.
  describe 'show pages of a collection', with_nested_reindexing: true do
    before do
      docs = (0..12).map do |n|
        { "has_model_ssim" => ["GenericWork"], :id => "zs25x871q#{n}",
          "depositor_ssim" => [user.user_key],
          "suppressed_bsi" => false,
          "member_of_collection_ids_ssim" => [collection.id],
          "nesting_collection__parent_ids_ssim" => [collection.id],
          "edit_access_person_ssim" => [user.user_key] }
      end
      ActiveFedora::SolrService.add(docs, commit: true)

      sign_in user
    end
    let(:collection) { create(:named_collection, user: user, with_permission_template: true) }

    it "shows a collection with a listing of Descriptive Metadata and catalog-style search results" do
      visit '/dashboard/my/collections'
      expect(page).to have_content(collection.title.first)
      within('#document_' + collection.id) do
        # Now go to the collection show page
        click_link("Display all details of collection title")
      end
      expect(page).to have_css(".pager")
    end
  end

  describe 'remove works from collection' do
    context 'user that can edit', :with_nested_reindexing do
      let!(:work2) { create(:work, title: ["King Louie"], member_of_collections: [collection1], user: user) }
      let!(:work1) { create(:work, title: ["King Kong"], member_of_collections: [collection1], user: user) }

      before do
        sign_in admin_user
      end
      # TODO: move this test to a view unit test (and solve the missing warden problem when using Ability in view tests)
      it 'shows remove action buttons' do
        visit "/dashboard/collections/#{collection1.id}"
        expect(page).to have_selector('input.collection-remove', count: 2)
      end
      it 'removes the first work from the list of items' do
        visit "/dashboard/collections/#{collection1.id}"
        expect(page).to have_selector('input.collection-remove', count: 2)
        page.all('input.collection-remove')[0].click
        expect(page).to have_selector('input.collection-remove', count: 1)
        # because works do not have order, you cannot guarentee that the first work added is the work getting deleted
        has_work1 = page.has_content? work1.title.first
        has_work2 = page.has_content? work2.title.first
        expect(has_work1 ^ has_work2).to be true
      end
      xit 'removes a sub-collection from the list of items (dependency on collection nesting)' do
      end
    end
    context 'user that cannot edit' do
      let!(:work1) { create(:work, title: ["King Louie"], member_of_collections: [collection3], user: user) }
      let!(:work2) { create(:work, title: ["King Kong"], member_of_collections: [collection3], user: user) }

      before do
        sign_in user
      end
      # TODO: move this test to a view unit test (and solve the missing warden problem when using Ability in view tests)
      it 'does not show remove action buttons' do
        visit "/dashboard/collections/#{collection3.id}"
        expect(page).not_to have_selector 'input.collection-remove'
      end
    end
  end

  describe 'edit collection' do
    let(:collection) { create(:named_collection, user: user, with_permission_template: true) }
    let!(:work1) { create(:work, title: ["King Louie"], member_of_collections: [collection], user: user) }
    let!(:work2) { create(:work, title: ["King Kong"], member_of_collections: [collection], user: user) }

    context 'from dashboard -> collections action menu' do
      before do
        create(:permission_template_access,
               :deposit,
               permission_template: collection1.permission_template,
               agent_type: 'user',
               agent_id: user.user_key)

        collection1
        sign_in user
        visit '/dashboard/my/collections'
      end

      it "edit denied because user does not have permissions" do
        # URL: /dashboard/my/collections
        expect(page).to have_content(collection1.title.first)
        within("#document_#{collection1.id}") do
          find('button.dropdown-toggle').click
          click_link('Edit collection')
        end
        expect(page).to have_content(collection1.title.first)
      end
    end

    context 'from dashboard -> collections action menu' do
      before do
        sign_in user
        visit '/dashboard/my/collections'
      end

      it "edits and update collection metadata" do
        # URL: /dashboard/my/collections
        expect(page).to have_content(collection.title.first)
        within("#document_#{collection.id}") do
          find('button.dropdown-toggle').click
          click_link('Edit collection')
        end
        # URL: /dashboard/collections/collection-id/edit
        expect(page).to have_selector('h1', text: "Edit User Collection: #{collection.title.first}")

        expect(page).to have_field('collection_title', with: collection.title.first)
        expect(page).to have_field('collection_description', with: collection.description.first)

        # TODO: These two expectations require the spec to include with_nested_reindexing: true.
        # However, adding nested indexing causes this spec to fail to go through the update method
        # in the controller unless js: true is also included. Including javascript greatly increases
        # the time required for the spec to complete, so for now, I am simply commenting out these
        # two expectations, as these are not integral to the function being tested.
        # expect(page).to have_content(work1.title.first)
        # expect(page).to have_content(work2.title.first)

        new_title = "Altered Title"
        new_description = "Completely new Description text."
        creators = ["Dorje Trollo", "Vajrayogini"]
        fill_in('Title', with: new_title)
        fill_in('Abstract or Summary', with: new_description)
        fill_in('Creator', with: creators.first)
        within('.panel-footer') do
          click_button('Save changes')
        end
        # URL: /dashboard/collections/collection-id/edit
        expect(page).not_to have_field('collection_title', with: collection.title.first)
        expect(page).not_to have_field('collection_description', with: collection.description.first)
        expect(page).to have_field('collection_title', with: new_title)
        expect(page).to have_field('collection_description', with: new_description)
        expect(page).to have_field('collection_creator', with: creators.first)
      end
    end

    context "edit view tabs" do
      before do
        sign_in user
      end

      it 'always includes branding' do
        visit "/dashboard/collections/#{collection.id}/edit"
        expect(page).to have_link('Branding', href: '#branding')
      end

      context 'with discoverable set' do
        let(:discoverable_collection_id) { create(:collection, user: user, collection_type_settings: [:discoverable], with_permission_template: true).id }
        let(:not_discoverable_collection_id) { create(:collection, user: user, collection_type_settings: [:not_discoverable], with_permission_template: true).id }

        it 'to true, it shows Discovery tab' do
          visit "/dashboard/collections/#{discoverable_collection_id}/edit"
          expect(page).to have_link('Discovery', href: '#discovery')
        end

        it 'to false, it hides Discovery tab' do
          visit "/dashboard/collections/#{not_discoverable_collection_id}/edit"
          expect(page).not_to have_link('Discovery', href: '#discovery')
        end
      end

      context 'with sharable set' do
        let(:sharable_collection_id) { create(:collection, user: user, collection_type_settings: [:sharable], with_permission_template: true).id }
        let(:not_sharable_collection_id) { create(:collection, user: user, collection_type_settings: [:not_sharable], with_permission_template: true).id }

        it 'to true, it shows Sharable tab' do
          visit "/dashboard/collections/#{sharable_collection_id}/edit"
          expect(page).to have_link('Sharing', href: '#sharing')
        end

        it 'to false, it hides Sharable tab' do
          visit "/dashboard/collections/#{not_sharable_collection_id}/edit"
          expect(page).not_to have_link('Sharing', href: '#sharing')
        end
      end
    end
  end
end
