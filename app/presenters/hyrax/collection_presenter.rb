module Hyrax
  class CollectionPresenter
    include ModelProxy
    include PresentsAttributes
    include ActionView::Helpers::NumberHelper
    attr_accessor :solr_document, :current_ability, :request

    # @param [SolrDocument] solr_document
    # @param [Ability] current_ability
    # @param [ActionDispatch::Request] request the http request context
    def initialize(solr_document, current_ability, request = nil)
      @solr_document = solr_document
      @current_ability = current_ability
      @request = request
    end

    # CurationConcern methods
    delegate :stringify_keys, :human_readable_type, :collection?, :representative_id,
             :to_s, to: :solr_document

    # Metadata Methods
    delegate :title, :description, :creator, :contributor, :subject, :publisher, :keyword, :language,
             :embargo_release_date, :lease_expiration_date, :license, :date_created,
             :resource_type, :based_near, :related_url, :identifier, :thumbnail_path,
             to: :solr_document

    # Terms is the list of fields displayed by
    # app/views/collections/_show_descriptions.html.erb
    def self.terms
      [:total_items, :size, :resource_type, :creator, :contributor, :keyword,
       :license, :publisher, :date_created, :subject, :language, :identifier,
       :based_near, :related_url]
    end

    def terms_with_values
      self.class.terms.select { |t| self[t].present? }
    end

    def [](key)
      case key
      when :size
        size
      when :total_items
        total_items
      else
        solr_document.send key
      end
    end

    def size
      number_to_human_size(@solr_document['bytes_lts']) || '0 Bytes'
    end

    def total_items
      solr = Valkyrie::MetadataAdapter.find(:index_solr).connection
      results = solr.get('select', params: { q: "member_of_collection_ids_ssim:id-#{id}",
                                             rows: 0,
                                             qt: 'standard' })
      results['response']['numFound'].to_i
    end
  end
end
