# frozen_string_literal: true
module Hyrax
  ##
  # Methods in this class are providing functionality previously supported by ActiveFedora::SolrQueryBuilder.
  # It includes methods to build and execute a query.
  class SolrQueryService < ::SearchBuilder # rubocop:disable Metrics/ClassLength
    class_attribute :query_service
    self.query_service = Hyrax.query_service

    attr_reader :query, :solr_service

    def initialize(query: [], solr_service: Hyrax::SolrService)
      @query = query
      @solr_service = solr_service
    end

    ##
    # @return [Hash] the results returned from solr for the current query
    def get
      solr_service.get(build)
    end

    ##
    # @return [Enumerable<SolrDocument>]
    def solr_documents
      get['response']['docs'].map { |doc| ::SolrDocument.new(doc) }
    end

    ##
    # @return [Array<String>] ids of documents matching the current query
    def get_ids # rubocop:disable Naming/AccessorMethodName
      results = get
      results['response']['docs'].map { |doc| doc['id'] }
    end

    ##
    # @return [Array<Valkyrie::Resource|ActiveFedora::Base>] objects matching the current query
    def get_objects(use_valkyrie: Hyrax.config.use_valkyrie?)
      ids = get_ids
      return ids.map { |id| ActiveFedora::Base.find(id) } unless use_valkyrie
      query_service.find_many_by_ids(ids: ids)
    end

    ##
    # @return [Integer] the number of results that match the query in solr
    def count
      solr_service.count(build)
    end

    ##
    # @return [String] the combined query that can be submitted to solr
    def build
      return 'id:NEVER_USE_THIS_ID' if @query.blank? # forces this method to always return a valid solr query
      @query.join(' AND ')
    end

    ##
    # @return [Hyrax::SolrQueryService] the existing service with the query reset to empty
    def reset
      @query = []
      self
    end

    ##
    # @param ids [Array] id_array the ids that you want included in the query
    # @return [Hyrax::SolrQueryService] the existing service with id query appended
    def with_ids(ids: [])
      ids = ids.reject(&:blank?)
      raise ArgumentError, "Expected there to be at least one non-blank id." if ids.blank?
      id_query = construct_query_for_ids(ids)
      @query += [id_query]
      self
    end

    ##
    # @param model [#to_s] a class from the model (e.g. Hyrax::Work, Hyrax::FileSet, etc.)
    # @return [SolrQueryService] the existing service with model query appended
    def with_model(model:)
      model_query = construct_query_for_model(model)
      @query += [model_query]
      self
    end

    ##
    # @param generic_type [String] (Default: Work)
    # @return [SolrQueryService] the existing service with model query appended
    def with_generic_type(generic_type: 'Work')
      # TODO: Generic type was originally stored as `sim`.  Since it is never multi-valued, it is moving to being stored
      #       as `si`.  Until a migration is created to correct existing solr docs, this query searches in both fields.
      field_pairs = { generic_type_si: generic_type, generic_type_sim: generic_type }
      type_query = construct_query_for_pairs(field_pairs, ' OR ', 'field')
      @query += [type_query]
      self
    end

    ##
    # @param field_pairs [Hash] a list of pairs of property name and values (e.g. { field1: values, field2: values })
    # @param join_with [String] the connector used to join the field pairs (default: ' AND ')
    # @param type [String] type of query to run. Either 'raw' or 'field' (default: 'field')
    # @return [SolrQueryService] the existing service with field_pair query appended
    def with_field_pairs(field_pairs: {}, join_with: default_join_with, type: 'field')
      pairs_query = construct_query_for_pairs(field_pairs, join_with, type)
      return self if pairs_query.blank?
      @query += [pairs_query]
      self
    end

    ##
    # @param ability [???] the user's abilities
    # @param action [Symbol] the action the user is taking (e.g. :index, :edit, :show, etc.) (default: :index)
    # @return [SolrQueryService] the existing service with access filters query appended
    def accessible_by(ability:, action: :index)
      access_filters_query = construct_query_for_ability(ability, action)
      @query += [access_filters_query] if access_filters_query.present?
      self
    end

    private

    # Construct a solr query for a list of ids
    # @param [Array] ids to be included in the query
    # @return [String] a solr query
    # @example
    #   construct_query_for_ids(['id1', 'id2'])
    #   # => "{!terms f=id}id1,id2"
    def construct_query_for_ids(ids)
      "{!terms f=#{Hyrax.config.id_field}}#{ids.join(',')}"
    end

    # Construct a solr query from a list of pairs (e.g. { field1: values, field2: values })
    # @param [Hash] field_pairs a list of pairs of property name and values
    # @param [String] join_with the value we're joining the clauses with (default: ' AND ')
    # @param [String] type of query to run. Either 'raw' or 'field' (default: 'field')
    # @return [String] a solr query
    # @example
    #   construct_query([['library_id_ssim', '123'], ['owner_ssim', 'Fred']])
    #   # => "_query_:\"{!field f=library_id_ssim}123\" AND _query_:\"{!field f=owner_ssim}Fred\""
    def construct_query_for_pairs(field_pairs, join_with = default_join_with, type = 'field')
      clauses = pairs_to_clauses(field_pairs, type)
      return "" if clauses.count.zero?
      return clauses.first if clauses.count == 1
      "(#{clauses.join(join_with)})"
    end

    # Construct a solr query from the model (e.g. Collection, Monograph)
    # @param [Class] model class
    # @return [String] a solr query
    # @example
    #   construct_query_for_model(Monograph)
    #   # => "_query_:\"{!field f=has_model_ssim}Monograph\""
    def construct_query_for_model(model)
      field_pairs = { "has_model_ssim" => model.to_s }
      construct_query_for_pairs(field_pairs)
    end

    # Construct a solr query based on a User's abilities and the action they taking
    # @param ability [???] the user's abilities
    # @param action [Symbol] the action the user is taking (e.g. :index, :edit, :show, etc.) (default: :index)
    # @return [String] a solr query
    # @example
    #   construct_query_for_ability(user, :edit)
    #   # => "(({!terms f=edit_access_group_ssim}public,user_group_A}) OR " \
    #           "edit_access_person_ssim:#{user@example.com})"
    def construct_query_for_ability(ability, action)
      permission_types = case action
                         when :index then [:discover, :read, :edit]
                         when :show, :read then [:read, :edit]
                         when :update, :edit, :create, :new, :destroy then [:edit]
                         end
      filters = gated_discovery_filters(permission_types, ability).join(' OR ')
      return "" if filters.blank?
      "(#{filters})"
    end

    def default_join_with
      ' AND '
    end

    # @param [Array<Array>] pairs a list of (key, value) pairs. The value itself may
    # @param [String] type  The type of query to run. Either 'raw' or 'field'
    # @return [Hash] a list of solr clauses
    def pairs_to_clauses(pairs, type)
      pairs.flat_map do |field, value|
        condition_to_clauses(field, value, type)
      end
    end

    # @param [String] field
    # @param [String, Array<String>] values
    # @param [String] type The type of query to run. Either 'raw' or 'field'
    # @return [Array<String>]
    def condition_to_clauses(field, values, type)
      values = Array(values)
      values << nil if values.empty?
      values.map do |value|
        if value.present?
          query_clause(type, field, value)
        else
          # Check that the field is not present. In SQL: "WHERE field IS NULL"
          "-#{field}:[* TO *]"
        end
      end
    end

    # Create a raw query clause suitable for sending to solr as an fq element
    # @param [String] type The type of query to run. Either 'raw' or 'field'
    # @param [String] key
    # @param [String] value
    def query_clause(type, key, value)
      "_query_:\"{!#{type} f=#{key}}#{value.gsub('"', '\"')}\""
    end
  end
end
