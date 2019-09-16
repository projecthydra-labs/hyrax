# frozen_string_literal: true

module Hyrax
  ##
  # Propagates visibility from a valkyrie Work to its FileSets
  class ResourceVisibilityPropagator
    ##
    # @!attribute [rw] source
    #   @return [#visibility]
    attr_accessor :source

    ##
    # @!attribute [r] embargo_manager
    #   @return [Hyrax::EmbargoManager]
    # @!attribute [r] lease_manager
    #   @return [Hyrax::LeaseManager]
    # @!attribute [r] persister
    #   @return [#save]
    # @!attribute [r] queries
    #   @returrn [Valkyrie::Persistence::CustomQueryContainer]
    attr_reader :embargo_manager, :lease_manager, :persister, :queries

    ##
    # @param source [#visibility] the object to propogate visibility from
    def initialize(source:,
                   embargo_manager: Hyrax::EmbargoManager,
                   lease_manager:   Hyrax::LeaseManager,
                   persister:       Hyrax.persister,
                   queries:         Hyrax.query_service.custom_queries)
      @persister       = persister
      @queries         = queries
      self.source      = source
      @embargo_manager = embargo_manager.new(resource: source)
      @lease_manager   = lease_manager.new(resource: source)
    end

    ##
    # @return [void]
    #
    # @raise [RuntimeError] if visibility propogation fails
    def propagate
      queries.find_child_filesets(resource: source).each do |file_set|
        file_set.visibility = source.visibility
        embargo_manager.copy_embargo_to(target: file_set)
        lease_manager.copy_lease_to(target: file_set)

        file_set.permission_manager.acl.save
        persister.save(resource: file_set)
      end
    end
  end
end
