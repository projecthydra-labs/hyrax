require 'spec_helper'

describe Hyrax::Configuration do
  subject { described_class.new }

  describe '#register_roles' do
    it 'yields a RoleRegistry' do
      expect { |b| subject.register_roles(&b) }.to yield_with_args(kind_of(Hyrax::RoleRegistry))
    end
  end
  it { is_expected.to delegate_method(:registered_role?).to(:role_registry) }
  it { is_expected.to delegate_method(:persist_registered_roles!).to(:role_registry) }

  describe '#default_active_workflow_name' do
    subject { described_class.new.default_active_workflow_name }
    it { is_expected.to eq('default') }
  end

  it { is_expected.to respond_to(:persistent_hostpath) }
  it { is_expected.to respond_to(:redis_namespace) }
  it { is_expected.to respond_to(:libreoffice_path) }
  it { is_expected.to respond_to(:browse_everything) }
  it { is_expected.to respond_to(:analytics) }
  it { is_expected.to respond_to(:citations) }
  it { is_expected.to respond_to(:max_notifications_for_dashboard) }
  it { is_expected.to respond_to(:activity_to_show_default_seconds_since_now) }
  it { is_expected.to respond_to(:arkivo_api) }
  it { is_expected.to respond_to(:active_deposit_agreement_acceptance) }
  it { is_expected.to respond_to(:batch_user_key) }
  it { is_expected.to respond_to(:audit_user_key) }
  it { is_expected.to respond_to(:upload_path) }
  it { is_expected.to respond_to(:always_display_share_button) }
  it { is_expected.to respond_to(:google_analytics_id) }
  it { is_expected.to respond_to(:analytic_start_date) }
  it { is_expected.to respond_to(:display_media_download_link) }
  it { is_expected.to respond_to(:permission_levels) }
  it { is_expected.to respond_to(:owner_permission_levels) }
  it { is_expected.to respond_to(:translate_uri_to_id) }
  it { is_expected.to respond_to(:translate_id_to_uri) }
  it { is_expected.to respond_to(:contact_email) }
  it { is_expected.to respond_to(:subject_prefix) }
  it { is_expected.to respond_to(:model_to_create) }
  it { is_expected.to respond_to(:feature_config_path) }
end
