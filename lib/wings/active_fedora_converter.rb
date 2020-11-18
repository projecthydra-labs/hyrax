# frozen_string_literal: true

require 'wings/converter_value_mapper'

module Wings
  ##
  # Converts `Valkyrie::Resource` objects to legacy `ActiveFedora::Base` objects.
  #
  # @example
  #   work     = GenericWork.new(title: ['Comet in Moominland'])
  #   resource = GenericWork.valkyrie_resource
  #
  #   ActiveFedoraConverter.new(resource: resource).convert == work # => true
  #
  # @note the `Valkyrie::Resource` object passed to this class **must** have an
  #   `#internal_resource` mapping it to an `ActiveFedora::Base` class.
  class ActiveFedoraConverter # rubocop:disable Metrics/ClassLength
    ##
    # Accesses the Class implemented for handling resource attributes
    # @return [Class]
    def self.attributes_class
      ActiveFedoraAttributes
    end

    ##
    # @params [Valkyrie::Resource] resource
    #
    # @return [ActiveFedora::Base]
    def self.convert(resource:)
      new(resource: resource).convert
    end

    ##
    # @!attribute [rw] resource
    #   @return [Valkyrie::Resource]
    attr_accessor :resource

    ##
    # @param [Valkyrie::Resource]
    def initialize(resource:)
      @resource = resource
    end

    ##
    # Accesses and parses the attributes from the resource through ConverterValueMapper
    #
    # @return [Hash] attributes with values mapped for building an ActiveFedora model
    def attributes
      @attributes ||= attributes_class.mapped_attributes(attributes: resource.attributes).select do |attr|
        active_fedora_class.supports_property?(attr)
      end
    end

    ##
    # @return [ActiveFedora::Base]
    def convert
      active_fedora_class.new(normal_attributes).tap do |af_object|
        af_object.id = id unless id.empty?
        normal_attributes.each_key { |key| af_object.send(:attribute_will_change!, key) }
        add_access_control_attributes(af_object)
        convert_members(af_object)
        convert_member_of_collections(af_object)
        convert_files(af_object)
      end
    end

    def active_fedora_class
      klass = begin
                resource.internal_resource.constantize
              rescue NameError
                Wings::ActiveFedoraClassifier.new(resource.internal_resource).best_model
              end

      return klass if klass <= ActiveFedora::Base

      ModelRegistry.lookup(klass)
    end

    ##
    # In the context of a Valkyrie resource, prefer to use the id if it
    # is provided and fallback to the first of the alternate_ids. If all else fails
    # then the id hasn't been minted and shouldn't yet be set.
    # @return [String]
    def id
      return resource[:id].to_s if resource[:id]&.is_a?(::Valkyrie::ID) && resource[:id].present?
      return "" unless resource.respond_to?(:alternate_ids)

      resource.alternate_ids.first.to_s
    end

    def self.DefaultWork(resource_class)
      Class.new(DefaultWork) do
        self.valkyrie_class = resource_class

        # extract AF properties from the Valkyrie schema;
        # skip reserved attributes, proctected properties, and those already defined
        resource_class.schema.each do |schema_key|
          next if resource_class.reserved_attributes.include?(schema_key.name)
          next if self.instance_methods.find { |x| x == schema_key.name }
          next if properties.keys.include?(schema_key.name.to_s)

          property schema_key.name, predicate: RDF::URI("http://hyrax.samvera.org/ns/wings##{schema_key.name}")
        end

        # nested attributes in AF don't inherit! this needs to be here until we can drop it completely.
        accepts_nested_attributes_for :nested_resource
      end
    end

    ##
    # A base model class for valkyrie resources that don't have corresponding
    # ActiveFedora::Base models.
    class DefaultWork < ActiveFedora::Base
      include Hyrax::WorkBehavior
      property :nested_resource, predicate: ::RDF::URI("http://example.com/nested_resource"), class_name: "Wings::ActiveFedoraConverter::NestedResource"

      class_attribute :valkyrie_class
      self.valkyrie_class = Hyrax::Resource

      class << self
        delegate :human_readable_type, to: :valkyrie_class

        def model_name(*)
          _hyrax_default_name_class.new(valkyrie_class)
        end

        def to_rdf_representation
          "Wings(#{valkyrie_class})"
        end
        alias inspect to_rdf_representation
        alias to_s inspect
      end

      def to_global_id
        GlobalID.create(valkyrie_class.new(id: id))
      end
    end

    class NestedResource < ActiveTriples::Resource
      property :title, predicate: ::RDF::Vocab::DC.title
      property :author, predicate: ::RDF::URI('http://example.com/ns/author')
      property :depositor, predicate: ::RDF::URI('http://example.com/ns/depositor')
      property :nested_resource, predicate: ::RDF::URI("http://example.com/nested_resource"), class_name: NestedResource
      property :ordered_authors, predicate: ::RDF::Vocab::DC.creator
      property :ordered_nested, predicate: ::RDF::URI("http://example.com/ordered_nested")

      def initialize(uri = RDF::Node.new, _parent = ActiveTriples::Resource.new)
        uri = if uri.try(:node?)
                RDF::URI("#nested_resource_#{uri.to_s.gsub('_:', '')}")
              elsif uri.to_s.include?('#')
                RDF::URI(uri)
              end
        super
      end

      include ::Hyrax::BasicMetadata
    end

    private

    def attributes_class
      self.class.attributes_class
    end

    def convert_members(af_object)
      return unless resource.respond_to?(:member_ids) && resource.member_ids
      # TODO: It would be better to find a way to add the members without resuming all the member AF objects
      af_object.ordered_members = resource.member_ids.map { |valkyrie_id| ActiveFedora::Base.find(valkyrie_id.to_s) }
    end

    def convert_member_of_collections(af_object)
      return unless resource.respond_to?(:member_of_collection_ids) && resource.member_of_collection_ids
      # TODO: It would be better to find a way to set the parent collections without resuming all the collection AF objects
      af_object.member_of_collections = resource.member_of_collection_ids.map { |valkyrie_id| ActiveFedora::Base.find(valkyrie_id.to_s) }
    end

    def convert_files(af_object)
      return unless resource.respond_to? :file_ids

      af_object.files = resource.file_ids.map do |fid|
        next if fid.blank?
        pcdm_file = Hydra::PCDM::File.new(fid.id)
        assign_association_target(af_object, pcdm_file)
      end.compact
    end

    def assign_association_target(af_object, pcdm_file)
      case pcdm_file.metadata_node.type
      when ->(types) { types.include?(RDF::URI.new('http://pcdm.org/use#OriginalFile')) }
        af_object.association(:original_file).target = pcdm_file
      when ->(types) { types.include?(RDF::URI.new('http://pcdm.org/use#ExtractedText')) }
        af_object.association(:extracted_text).target = pcdm_file
      when ->(types) { types.include?(RDF::URI.new('http://pcdm.org/use#Thumbnail')) }
        af_object.association(:thumbnail).target = pcdm_file
      else
        pcdm_file
      end
    end

    # Normalizes the attributes parsed from the resource
    #   (This ensures that scalar values are passed to the constructor for the
    #   ActiveFedora::Base Class)
    # @return [Hash]
    def normal_attributes
      attributes.each_with_object({}) do |(attr, value), hash|
        property = active_fedora_class.properties[attr.to_s]
        hash[attr] = if property.nil?
                       value
                     elsif property.multiple?
                       Array.wrap(value)
                     elsif Array.wrap(value).length < 2
                       Array.wrap(value).first
                     else
                       value
                     end
      end
    end

    # Add attributes from resource which aren't AF properties into af_object
    def add_access_control_attributes(af_object)
      return unless af_object.is_a? Hydra::AccessControl
      cache = af_object.permissions.to_a

      # if we've saved this before, it has a cache that won't clear
      # when setting permissions! we need to reset it manually and
      # rewrite with the values already in there, or saving will fail
      # to delete cached items
      af_object.permissions.reset if af_object.persisted?

      af_object.permissions = cache.map do |permission|
        permission.access_to_id = resource.try(:access_to)&.id
        permission
      end
    end
  end
end
