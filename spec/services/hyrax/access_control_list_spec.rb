# frozen_string_literal: true

RSpec.describe Hyrax::AccessControlList do
  subject(:acl) do
    described_class.new(resource:      resource,
                        persister:     persister,
                        query_service: query_service)
  end

  let(:permission)    { build(:permission) }
  let(:adapter)       { Valkyrie::MetadataAdapter.find(:test_adapter) }
  let(:persister)     { adapter.persister }
  let(:query_service) { adapter.query_service }

  let(:resource) do
    r = build(:hyrax_resource)
    Hyrax.persister.save(resource: r)
  end

  describe 'grant DSL' do
    let(:mode) { :read }
    let(:user) { ::User.find(permission.agent) }

    describe '#grant' do
      it 'grants a permission' do
        expect { acl.grant(mode).to(user) }
          .to change { acl.permissions }
          .to contain_exactly(have_attributes(mode:      mode,
                                              agent:     user.id.to_s,
                                              access_to: resource.id))
      end
    end

    describe '#revoke' do
      before do
        acl << permission
        acl.save
      end

      it 'revokes a permission' do
        expect { acl.revoke(mode).from(user) }
          .to change { acl.permissions }
          .to be_empty
      end
    end
  end

  describe '#permissions' do
    it 'is empty by default' do
      expect(acl.permissions).to be_empty
    end
  end

  describe '#<<' do
    it 'adds the new permission with access_to' do
      expect { acl << permission }
        .to change { acl.permissions }
        .to contain_exactly(have_attributes(mode:      permission.mode,
                                            agent:     permission.agent,
                                            access_to: resource.id))
    end
  end

  describe '#delete' do
    it 'does nothing when the permission is not in the set' do
      expect { acl.delete(permission) }
        .not_to change { acl.permissions }
        .from be_empty
    end

    context 'when the permission exists' do
      before { acl << permission }

      it 'removes the permission' do
        expect { acl.delete(permission) }
          .to change { acl.permissions }
          .from(contain_exactly(have_attributes(mode:      permission.mode,
                                                agent:     permission.agent,
                                                access_to: resource.id)))
          .to be_empty
      end
    end
  end

  describe '#save' do
    it 'leaves permissions unchanged by default' do
      expect { acl.save }
        .not_to change { acl.permissions }
        .from be_empty
    end

    context 'with additions' do
      let(:permissions)      { [permission, other_permission] }
      let(:other_permission) { build(:permission, mode: 'edit') }

      before { permissions.each { |p| acl << p } }

      it 'saves the permission policies' do
        expect { acl.save }
          .to change { Hyrax::AccessControl.for(resource: resource, query_service: acl.query_service).permissions }
          .to contain_exactly(*permissions)
      end
    end

    context 'with deletions' do
      let(:permissions)      { [permission, other_permission] }
      let(:other_permission) { build(:permission, mode: 'edit') }

      before do
        permissions.each { |p| acl << p }
        acl.save
      end

      it 'deletes the permission policy' do
        delete_me = acl.permissions.first
        acl.delete(delete_me)
        rest = acl.permissions.clone

        expect { acl.save }
          .to change { Hyrax::AccessControl.for(resource: resource, query_service: acl.query_service).permissions }
          .to contain_exactly(*rest)
      end
    end
  end
end
