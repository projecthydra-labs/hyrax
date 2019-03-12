# frozen_string_literal: true

module Wings
  module Valkyrie
    class QueryService
      attr_reader :adapter
      extend Forwardable
      def_delegator :adapter, :resource_factory

      # @param adapter [Wings::Valkyrie::MetadataAdapter] The adapter which holds the resource_factory for this query_service.
      def initialize(adapter:)
        @adapter = adapter
      end

      # Find a record using a Valkyrie ID, and map it to a Valkyrie Resource
      # @param [Valkyrie::ID, String] id
      # @return [Valkyrie::Resource]
      # @raise [Valkyrie::Persistence::ObjectNotFoundError]
      def find_by(id:)
        id = ::Valkyrie::ID.new(id.to_s) if id.is_a?(String)
        validate_id(id)
        resource_factory.to_resource(object: ::ActiveFedora::Base.find(id.to_s))
      rescue ::ActiveFedora::ObjectNotFoundError
        raise ::Valkyrie::Persistence::ObjectNotFoundError
      end

      # Find all work/collection records, and map to Valkyrie Resources
      # @return [Array<Valkyrie::Resource>]
      def find_all
        klasses = Hyrax.config.curation_concerns.append(::Collection)
        objects = ::ActiveFedora::Base.all.select do |object|
          klasses.include? object.class
        end
        objects.map do |id|
          resource_factory.to_resource(object: id)
        end
      end

      # Find all work/collection records of a given model, and map to Valkyrie Resources
      # @param [Valkyrie::ResourceClass]
      # @return [Array<Valkyrie::Resource>]
      def find_all_of_model(model:)
        find_model = model.internal_resource
        objects = ::ActiveFedora::Base.all.select do |object|
          object.class == find_model
        end
        objects.map do |id|
          resource_factory.to_resource(object: id)
        end
      end

      # Find an array of record using Valkyrie IDs, and map them to Valkyrie Resources
      # @param [Array<Valkyrie::ID, String>] ids
      # @return [Array<Valkyrie::Resource>]
      def find_many_by_ids(ids:)
        ids = ids.uniq
        ids.map do |id|
          begin
            find_by(id: id)
          rescue ::Valkyrie::Persistence::ObjectNotFoundError
            nil
          end
        end.compact
      end

      # Constructs a Valkyrie::Persistence::CustomQueryContainer using this query service
      # @return [Valkyrie::Persistence::CustomQueryContainer]
      def custom_queries
        @custom_queries ||= ::Valkyrie::Persistence::CustomQueryContainer.new(query_service: self)
      end

      private

        # Determines whether or not an Object is a Valkyrie ID
        # @param [Object] id
        # @raise [ArgumentError]
        def validate_id(id)
          raise ArgumentError, 'id must be a Valkyrie::ID' unless id.is_a? ::Valkyrie::ID
        end
    end
  end
end
