require 'active_fedora/noid'

module Hyrax
  module Noid
    extend ActiveSupport::Concern

    ## This overrides the default behavior, which is to ask Fedora for an id
    # @see ActiveFedora::Persistence.assign_id
    def assign_id
      service.mint if Hyrax.config.enable_noids?
    end

    private

      def service
        @service ||= ActiveFedora::Noid::Service.new
      end
  end
end
