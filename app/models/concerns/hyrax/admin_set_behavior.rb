module Hyrax
  # There is an interplay between an AdminSet and a PermissionTemplate. Given
  # that AdminSet is an ActiveFedora::Base and PermissionTemplate is ActiveRecord::Base
  # we don't have the usual :has_many or :belongs_to methods to assist in defining that
  # relationship. However, from a conceptual standpoint:
  #
  # * An AdminSet has_one :permission_tempate
  # * A PermissionTemplate belongs_to :admin_set
  #
  # When an object is added as a member of an AdminSet, the AdminSet's associated
  # PermissionTemplate is applied to that object (e.g. some of the object's attributes
  # are updated as per the rules of the permission template)
  #
  # @see AdminSet
  # @see Hyrax::PermissionTemplate
  # @see Hyrax::AdminSetService
  # @see Hyrax::Forms::PermissionTemplateForm for validations and creation process
  # @see Hyrax::DefaultAdminSetActor
  # @see Hyrax::ApplyPermissionTemplateActor  module AdminSetBehavior
  module AdminSetBehavior
    extend ActiveSupport::Concern

    include Hydra::AccessControls::WithAccessRight
    include Hyrax::Noid
    include Hyrax::HumanReadableType
    include Hyrax::HasRepresentative

    included do
      DEFAULT_ID = 'admin_set/default'.freeze

      def self.default_set?(id)
        id == DEFAULT_ID
      end

      validates_with HasOneTitleValidator
      class_attribute :human_readable_short_description, :indexer
      self.indexer = Hyrax::AdminSetIndexer
      property :title, predicate: ::RDF::Vocab::DC.title do |index|
        index.as :stored_searchable, :facetable
      end
      property :description, predicate: ::RDF::Vocab::DC.description do |index|
        index.as :stored_searchable
      end

      property :creator, predicate: ::RDF::Vocab::DC11.creator do |index|
        index.as :symbol
      end

      has_many :members,
               predicate: ::RDF::Vocab::DC.isPartOf,
               class_name: 'ActiveFedora::Base'

      before_destroy :check_if_not_default_set, :check_if_empty
      after_destroy :destroy_permission_template
    end

    def to_s
      title.present? ? title : 'No Title'
    end

    # @api public
    # A bit of an analogue for a `has_one :admin_set` as it crosses from Fedora to the DB
    # @return [Hyrax::PermissionTemplate]
    # @raise [ActiveRecord::RecordNotFound]
    def permission_template
      Hyrax::PermissionTemplate.find_by!(admin_set_id: id)
    end

    # @api public
    #
    # @return [Sipity::Workflow]
    # @raise [ActiveRecord::RecordNotFound]
    def active_workflow
      Sipity::Workflow.find_active_workflow_for(admin_set_id: id)
    end

    private

      def destroy_permission_template
        permission_template.destroy
      rescue ActiveRecord::RecordNotFound
        true
      end

      def check_if_empty
        return true if members.empty?
        errors[:base] << I18n.t('hyrax.admin.admin_sets.delete.error_not_empty')
        throw :abort
      end

      def check_if_not_default_set
        return true unless AdminSet.default_set?(id)
        errors[:base] << I18n.t('hyrax.admin.admin_sets.delete.error_default_set')
        throw :abort
      end
  end
end
