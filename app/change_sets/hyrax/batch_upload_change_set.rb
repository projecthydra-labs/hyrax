module Hyrax
  class BatchUploadChangeSet < WorkChangeSet
    # include HydraEditor::Form::Permissions

    self.exclude_fields = [:title, :resource_type]

    attr_accessor :payload_concern # a Class name: what is form creating a batch of?

    def self.work_klass
      ::BatchUploadItem
    end

    autocreate_fields!

    # On the batch upload, title is set per-file.
    def primary_terms
      super - [:title]
    end

    # # On the batch upload, title is set per-file.
    # def secondary_terms
    #   super - [:title]
    # end

    # Override of ActiveModel::Model name that allows us to use our custom name class
    def self.model_name
      @_model_name ||= begin
        namespace = parents.detect do |n|
          n.respond_to?(:use_relative_model_naming?) && n.use_relative_model_naming?
        end
        Name.new(work_klass, namespace)
      end
    end

    def model_name
      self.class.model_name
    end

    # This is required for routing to the BatchUploadController
    # def to_model
    #   self
    # end

    # A model name that provides correct routes for the BatchUploadController
    # without changing the param key.
    #
    # Example:
    #   name = Name.new(GenericWork)
    #   name.param_key
    #   # => 'generic_work'
    #   name.route_key
    #   # => 'batch_uploads'
    #
    class Name < ::ActiveModel::Name
      def initialize(klass, namespace = nil, name = nil)
        super
        @route_key          = "batch_uploads"
        @singular_route_key = ActiveSupport::Inflector.singularize(@route_key)
        @route_key << "_index" if @plural == @singular
      end
    end
  end
end
