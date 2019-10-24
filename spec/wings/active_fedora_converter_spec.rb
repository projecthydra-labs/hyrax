# frozen_string_literal: true
require 'spec_helper'
require 'wings'
require 'wings/active_fedora_converter'

RSpec.describe Wings::ActiveFedoraConverter, :clean_repo do
  subject(:converter) { described_class.new(resource: resource) }
  let(:attributes)    { { id: id } }
  let(:id)            { 'moomin_id' }
  let(:resource)      { work.valkyrie_resource }
  let(:work)          { GenericWork.new(attributes) }

  describe '.convert' do
    it 'returns the ActiveFedora model' do
      expect(described_class.convert(resource: resource)).to eq work
    end
  end

  describe '#convert' do
    it 'returns the ActiveFedora model' do
      expect(converter.convert).to eq work
    end

    context 'when given a valkyrie native model' do
      let(:resource) { klass.new }

      let(:klass) do
        class ConverterDummyResource < Valkyrie::Resource; end
        ConverterDummyResource
      end

      it 'gives a default work' do
        expect(converter.convert)
          .to be_a Wings::ActiveFedoraConverter::DefaultWork
      end

      context 'and it is registered' do
        let(:resource) { build(:hyrax_work) }

        it 'maps to the registered ActiveFedora class' do
          expect(converter.convert).to be_a Hyrax::Test::SimpleWorkLegacy
        end
      end
    end

    context 'when given a valkyrie Admin Set' do
      let(:resource) { FactoryBot.valkyrie_create(:hyrax_admin_set) }

      it 'gives an AdminSet' do
        expect(converter.convert).to be_a AdminSet
      end
    end

    context 'when given a valkyrie Work' do
      let(:resource) { FactoryBot.valkyrie_create(:hyrax_work) }

      it 'gives a work' do
        expect(converter.convert).to be_work
      end

      context 'with members' do
        let(:resource)   { FactoryBot.valkyrie_create(:hyrax_work, :with_member_works) }
        let(:member_ids) { resource.member_ids.map(&:id) }

        it 'saves members' do
          expect(converter.convert).to have_attributes(member_ids: member_ids)
        end

        it 'can access member models from converted object' do
          expect(converter.convert.members)
            .to contain_exactly(an_instance_of(Hyrax::Test::SimpleWorkLegacy),
                                an_instance_of(Hyrax::Test::SimpleWorkLegacy))
        end
      end

      context 'as Admin Set member' do
        let(:admin_set_id) { AdminSet.find_or_create_default_admin_set_id }

        before { resource.admin_set_id = admin_set_id }

        it 'is a member of the admin set' do
          expect(converter.convert.admin_set)
            .to eq AdminSet.find(AdminSet::DEFAULT_ID)
        end
      end
    end

    context 'when given a valkyrie Collection' do
      let(:resource) { FactoryBot.valkyrie_create(:hyrax_collection) }

      it 'gives a collection' do
        expect(converter.convert).to be_collection
      end

      it 'maps to an application Collection model' do
        expect(converter.convert).to be_a ::Collection
      end

      it 'has the given collection type' do
        expect(converter.convert.collection_type.to_global_id.to_s).to eq resource.collection_type_gid
      end

      context 'with work members' do
        let(:resource) { FactoryBot.valkyrie_create(:hyrax_collection, :with_member_works) }

        it 'retains the members' do
          expect(converter.convert).to have_attributes member_ids: resource.member_ids.map(&:id)
        end
      end

      context 'with collection members' do
        let(:resource) { FactoryBot.valkyrie_create(:hyrax_collection, :with_member_collections) }

        it 'retains the members' do
          expect(converter.convert).to have_attributes member_ids: resource.member_ids.map(&:id)
        end
      end
    end

    context 'with attributes' do
      let(:attributes) do
        FactoryBot.attributes_for(:generic_work)
      end

      it 'repopulates the attributes' do
        expect(converter.convert).to have_attributes(attributes)
      end

      it 'populates reflections'
    end

    context 'with an embargo' do
      let(:work) { FactoryBot.create(:embargoed_work) }

      it 'repopulates the embargo' do
        expect(converter.convert).to have_attributes(embargo_id: work.embargo_id)
      end

      it 'repopulates the embargo as a model' do
        expect(converter.convert).to have_attributes(embargo: work.embargo)
      end
    end

    context 'with a lease' do
      let(:work) { FactoryBot.create(:leased_work) }

      it 'repopulates the lease' do
        expect(converter.convert).to have_attributes(lease_id: work.lease_id)
      end
    end

    context 'with a generic work with _id attributes' do
      let(:work) { FactoryBot.create(:work_with_representative_file, with_admin_set: true) }
      before do
        work.thumbnail_id = work.representative_id
      end

      it 'repopulates the _id attributes' do
        expect(converter.convert).to have_attributes(
          representative_id: work.representative_id,
          thumbnail_id: work.thumbnail_id,
          access_control_id: work.access_control_id,
          admin_set_id: work.admin_set_id
        )
      end
    end

    context 'when setting ACLs' do
      let(:resource)    { valkyrie_create(:hyrax_resource) }
      let(:permissions) { Hyrax::PermissionManager.new(resource: resource) }
      let(:user_key)    { create(:user).user_key }

      it 'converts ACLs' do
        permissions.read_users = [user_key]

        expect { permissions.acl.save }
          .to change { described_class.new(resource: resource).convert }
          .to have_attributes(read_users: contain_exactly(user_key))
      end

      context 'when ACLs exist' do
        let(:work)     { FactoryBot.create(:public_work) }
        let(:resource) { work.valkyrie_resource }

        it 'can delete ACLs' do
          permissions.read_groups = []

          expect { permissions.acl.save }
            .to change { described_class.new(resource: resource).convert }
            .from(have_attributes(read_groups: contain_exactly('public')))
            .to have_attributes(read_groups: be_empty)
        end
      end
    end

    context 'when converting to ACL directly' do
      let(:resource) { FactoryBot.build(:access_control) }

      context 'when empty' do
        let(:resource) { Hyrax::AccessControl.new }

        it 'gives an empty acl' do
          expect(converter.convert).to have_attributes permissions: be_empty
        end
      end

      context 'with permissions' do
        it 'converts to an ACL with permissions' do
          agent = resource.permissions.first.agent
          mode  = resource.permissions.first.mode

          expect(converter.convert)
            .to have_attributes permissions: contain_exactly(grant_permission(mode)
                                                             .to_user(agent))
        end
      end

      context 'with an #access_to grant' do
        let(:resource) { FactoryBot.build(:access_control, :with_target) }

        it 'applies the access target to permissions' do
          agent = resource.permissions.first.agent
          mode  = resource.permissions.first.mode

          expect(converter.convert)
            .to have_attributes permissions: contain_exactly(grant_permission(mode)
                                                               .on(resource.access_to)
                                                               .to_user(agent))
        end
      end

      context 'with existing access controls' do
        let(:adapter)  { Wings::Valkyrie::MetadataAdapter.new }
        let(:discover) { build(:permission, mode: :discover, access_to: resource.access_to) }
        let(:resource) { work.permission_delegate.valkyrie_resource }
        let(:work)     { create(:generic_work) }

        it 'can delete permissions' do
          resource.permissions = []

          expect(converter.convert).to have_attributes permissions: be_empty
        end

        it 'can persist deleted permissions' do
          resource.permissions = []

          expect { adapter.persister.save(resource: resource) }
            .to change { work.reload.permissions }
            .to be_empty
        end

        it 'can replace new permissions to the work' do
          resource.permissions = [discover]

          expect { adapter.persister.save(resource: resource) }
            .to change { work.reload.permissions }
            .to contain_exactly grant_permission(:discover).to_user(discover.agent).on(work.id)
        end

        it 'can persist new permissions to the work' do
          existing_permission_expectations = resource.permissions.map do |p|
            grant_permission(p.mode).to_user(p.agent).on(work.id)
          end

          resource.permissions << discover

          expect { adapter.persister.save(resource: resource) }
            .to change { work.reload.permissions }
            .to contain_exactly(grant_permission(:discover).to_user(discover.agent).on(work.id),
                                *existing_permission_expectations)
        end

        it 'can persist group permissions to the work' do
          existing_permission_expectations = resource.permissions.map do |p|
            grant_permission(p.mode).to_user(p.agent).on(work.id)
          end

          public_read = build(:permission, mode: :read, access_to: resource.access_to, agent: 'group/public')
          resource.permissions << public_read

          expect { adapter.persister.save(resource: resource) }
            .to change { work.reload.permissions }
            .to contain_exactly(grant_permission(:read).to_group('public').on(work.id),
                                *existing_permission_expectations)
        end
      end
    end

    context 'with relationships' do
      subject(:factory) { Wings::ModelTransformer.new(pcdm_object: pcdm_object) }

      let(:resource) { subject.build }

      context 'for member_of_collections' do
        let(:pcdm_object) { collection1 }

        let(:collection1) { build(:public_collection_lw, id: 'col1', title: ['Collection 1']) }
        let(:collection2) { build(:public_collection_lw, id: 'col2', title: ['Collection 2']) }
        let(:collection3) { build(:public_collection_lw, id: 'col3', title: ['Collection 3']) }

        before do
          collection1.member_of_collections = [collection2, collection3]
          collection1.save!
        end

        it 'converts member_of_collection_ids back to af_object' do
          expect(converter.convert.member_of_collections.map(&:id)).to match_array [collection2.id, collection3.id]
        end
      end

      context 'for members' do
        let(:pcdm_object) { work1 }

        let(:work1)       { build(:work, id: 'wk1', title: ['Work 1']) }
        let(:work2)       { build(:work, id: 'wk2', title: ['Work 2']) }
        let(:work3)       { build(:work, id: 'wk3', title: ['Work 3']) }

        before do
          work1.ordered_members = [work2, work3]
          work1.save!
        end

        it 'converts member_of_collection_ids back to af_object' do
          expect(converter.convert.members.map(&:id)).to match_array [work3.id, work2.id]
        end

        it 'preserves order across conversion' do
          expect(converter.convert.ordered_member_ids).to eq [work2.id, work3.id]
        end
      end
    end
  end
end
