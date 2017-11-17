module Hyrax
  module FileSetBehavior
    extend ActiveSupport::Concern
    include Hyrax::WithEvents
    # include Hydra::Works::FileSetBehavior
    include Hydra::Works::MimeTypes
    # include Hydra::Works::VirusCheck
    include Hyrax::FileSet::Characterization
    include Hydra::WithDepositor
    include Serializers
    include Hyrax::Noid
    include Hyrax::FileSet::Derivatives
    include Permissions
    include Hyrax::FileSet::BelongsToWorks
    include HumanReadableType
    include CoreMetadata
    include Hyrax::BasicMetadata
    include Naming
    # include Hydra::AccessControls::Embargoable
    include GlobalID::Identification

    included do
      attr_accessor :file
      self.human_readable_type = 'File'

      attribute :file_identifiers, Valkyrie::Types::Set
      attribute :file_nodes, Valkyrie::Types::Set.member(FileNode.optional)
      attribute :member_ids, Valkyrie::Types::Array

      delegate :width, :height, :mime_type, :size, to: :original_file, allow_nil: true
      delegate :md5, :sha1, :sha256, to: :original_file_checksum, allow_nil: true
    end

    def original_file
      file_nodes.find(&:original_file?)
    end

    def representative_id
      to_param
    end

    def thumbnail_id
      to_param
    end

    # Cast to a SolrDocument by querying from Solr
    def to_presenter
      CatalogController.new.fetch(id).last
    end

    # @return [Boolean] whether this instance is a Hydra::Works Collection.
    def collection?
      false
    end

    # @return [Boolean] whether this instance is a Hydra::Works Generic Work.
    def work?
      false
    end

    # @return [Boolean] whether this instance is a Hydra::Works::FileSet.
    def file_set?
      true
    end

    def in_works
      Hyrax::Queries.find_inverse_references_by(resource: self, property: :member_ids)
    end
  end
end
