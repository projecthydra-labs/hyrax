# frozen_string_literal: true
module Hyrax
  module Workflow
    ##
    # Produces a list of workflow-ready objects for a given user.
    class ActionableObjects
      include Enumerable

      ##
      # @!attribute [rw] user
      #   @return [::User]
      attr_accessor :user

      ##
      # @param [::User] user
      def initialize(user:)
        @user = user
      end

      ##
      # @return [Hyrax::Workflow::StatePresenter]
      def each
        return enum_for(:each) unless block_given?

        gids_and_states = PermissionQuery
                          .scope_entities_for_the_user(user: user)
                          .pluck(:proxy_for_global_id, :workflow_state_id)

        return if gids_and_states.empty?

        ids = gids_and_states.map { |str, _| GlobalID.new(str).model_id }
        docs = Hyrax::SolrQueryService.new.with_ids(ids: ids).solr_documents

        docs.each do |solr_doc|
          yield solr_doc
        end
      end
    end
  end
end
