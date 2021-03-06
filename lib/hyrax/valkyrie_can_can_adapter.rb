# frozen_string_literal: true

module Hyrax
  ##
  # A `CanCan::ModelAdapter` for valkyrie resources
  class ValkyrieCanCanAdapter < CanCan::ModelAdapters::AbstractAdapter
    ##
    # @param [Class] member_class
    def self.for_class?(member_class)
      member_class == Hyrax::Resource ||
        member_class < Hyrax::Resource
    end

    ##
    # @param [Class] model_class
    # @param [String] id
    #
    # @return [Hyrax::Resource]
    #
    # @raise Hyrax::ObjectNotFoundError
    def self.find(_model_class, id)
      return Hyrax.query_service.find_by(id: id) unless Hyrax.config.enable_noids?
      Hyrax.query_service.find_by_alternate_identifier(alternate_identifier: id)
    rescue Valkyrie::Persistence::ObjectNotFoundError => err
      raise Hyrax::ObjectNotFoundError, err.message
    end
  end
end
