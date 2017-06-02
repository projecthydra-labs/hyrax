# -*- encoding : utf-8 -*-
module Hyrax
  module SolrDocumentBehavior
    extend ActiveSupport::Concern
    include Hydra::Works::MimeTypes
    include Hyrax::Permissions::Readable
    include Hyrax::SolrDocument::Export
    include Hyrax::SolrDocument::Characterization
    include Hyrax::SolrDocument::Metadata

    # Add a schema.org itemtype
    def itemtype
      ResourceTypesService.microdata_type(resource_type.first)
    end

    def title_or_label
      return label if title.blank?
      title.join(', ')
    end

    def to_param
      id
    end

    def to_s
      title_or_label
    end

    class ModelWrapper
      def initialize(model, id)
        @model = model
        @id = id
      end

      def persisted?
        true
      end

      def to_param
        @id
      end

      def model_name
        @model.model_name
      end

      def to_partial_path
        @model._to_partial_path
      end

      def to_global_id
        URI::GID.build app: GlobalID.app, model_name: model_name.name, model_id: @id
      end
    end
    ##
    # Offer the source (ActiveFedora-based) model to Rails for some of the
    # Rails methods (e.g. link_to).
    # @example
    #   link_to '...', SolrDocument(:id => 'bXXXXXX5').new => <a href="/dams_object/bXXXXXX5">...</a>
    def to_model
      @model ||= ModelWrapper.new(hydra_model, id)
    end

    def collection?
      hydra_model == ::Collection
    end

    # Method to return the ActiveFedora model
    def hydra_model
      first(Solrizer.solr_name('has_model', :symbol)).constantize
    end

    def depositor(default = '')
      val = first(Solrizer.solr_name('depositor'))
      val.present? ? val : default
    end

    def creator
      descriptor = hydra_model.index_config[:creator].behaviors.first
      fetch(Solrizer.solr_name('creator', descriptor), [])
    end

    def visibility
      @visibility ||= if embargo_release_date.present?
                        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_EMBARGO
                      elsif lease_expiration_date.present?
                        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_LEASE
                      elsif public?
                        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PUBLIC
                      elsif registered?
                        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_AUTHENTICATED
                      else
                        Hydra::AccessControls::AccessRight::VISIBILITY_TEXT_VALUE_PRIVATE
                      end
    end

    # Find the solr documents for the collections this object belongs to
    # TODO: can we remove this method now?
    def collections
      return @collections if @collections
      query = 'id:' + collection_ids.map { |id| '"' + id + '"' }.join(' OR ')
      result = Blacklight.default_index.connection.select(params: { q: query })
      @collections = result['response']['docs'].map do |hash|
        ::SolrDocument.new(hash)
      end
    end
  end
end
