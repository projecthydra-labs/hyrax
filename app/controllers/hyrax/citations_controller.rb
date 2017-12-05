module Hyrax
  class CitationsController < ApplicationController
    include WorksControllerBehavior
    include Breadcrumbs
    include DenyAccessOverrideBehavior

    # Overrides decide_layout from WorksControllerBehavior
    with_themed_layout '1_column'

    before_action :load_and_authorize_work, only: :work
    before_action :load_and_authorize_file_set, only: :file
    before_action :build_breadcrumbs, only: [:work, :file]

    def work
      show
    end

    def file
      # We set _@presenter_ here so it isn't set in WorksControllerBehavior#presenter
      # which is intended to find works (not files)
      @presenter = FileSetPresenter.new(@file_set, current_ability, request)
      show
    end

    private

      def load_and_authorize_work
        resource = Hyrax::Queries.find_by(id: Valkyrie::ID.new(params[:id]))
        raise Hyrax::ObjectNotFoundError("Couldn't find work with 'id'=#{params[:id]}") unless resource.work?
        @work = resource
        authorize! :citation, @work
      end

      def load_and_authorize_file_set
        resource = Hyrax::Queries.find_by(id: Valkyrie::ID.new(params[:id]))
        raise Hyrax::ObjectNotFoundError("Couldn't find file set with 'id'=#{params[:id]}") unless resource.file_set?
        @file_set = resource
        authorize! :citation, @file_set
      end

      def show_presenter
        WorkShowPresenter
      end
  end
end
