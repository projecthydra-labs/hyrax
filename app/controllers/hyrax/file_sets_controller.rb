module Hyrax
  class FileSetsController < ApplicationController
    include Blacklight::Base
    include Blacklight::AccessControls::Catalog
    include Hyrax::Breadcrumbs

    before_action :authenticate_user!, except: [:show, :citation, :stats]
    load_and_authorize_resource class: ::FileSet, except: :show
    before_action :build_breadcrumbs, only: [:show, :edit, :stats]

    # provides the help_text view method
    helper PermissionsHelper

    helper_method :curation_concern
    include Hyrax::ParentContainer
    copy_blacklight_config_from(::CatalogController)

    class_attribute :show_presenter, :change_set_class
    self.show_presenter = Hyrax::FileSetPresenter
    self.change_set_class = Hyrax::Forms::FileSetEditForm

    # A little bit of explanation, CanCan(Can) sets the @file_set via the .load_and_authorize_resource
    # method. However the interface for various CurationConcern modules leverages the #curation_concern method
    # Thus we have file_set and curation_concern that are aliases for each other.
    attr_accessor :file_set
    alias curation_concern file_set
    private :file_set=
    alias curation_concern= file_set=
    private :curation_concern=
    helper_method :file_set

    # routed to /files/new
    def new; end

    # routed to /files/:id/edit
    def edit
      initialize_edit_form
    end

    # routed to /files (POST)
    def create
      file = params.fetch(:file_set, {}).fetch(:files, []).detect { |f| f.respond_to?(:original_filename) }
      return render_json_response(response_type: :bad_request, options: { message: 'Error! No file uploaded', description: 'missing file' }) unless file
      return empty_file_response(file) if empty_file?(file)
      process_non_empty_file(file: file)
    rescue RSolr::Error::Http => error
      logger.error "FileSetController::create rescued #{error.class}\n\t#{error}\n #{error.backtrace.join("\n")}\n\n"
      render_json_response(response_type: :internal_error, options: { message: 'Error occurred while creating a FileSet.' })
    ensure
      file.tempfile.delete if file.respond_to?(:tempfile) # remove tempfile (only if it is a temp file)
    end

    # routed to /files/:id
    def show
      respond_to do |wants|
        wants.html { presenter }
        wants.json { presenter }
        additional_response_formats(wants)
      end
    end

    def destroy
      parent = curation_concern.parent
      actor.destroy
      redirect_to [main_app, parent], notice: 'The file has been deleted.'
    end

    # routed to /files/:id (PUT)
    def update
      if attempt_update
        after_update_response
      else
        after_update_failure_response
      end
    rescue RSolr::Error::Http => error
      flash[:error] = error.message
      logger.error "FileSetsController::update rescued #{error.class}\n\t#{error.message}\n #{error.backtrace.join("\n")}\n\n"
      render action: 'edit'
    end

    # routed to /files/:id/stats
    def stats
      @stats = FileUsage.new(params[:id])
    end

    # routed to /files/:id/citation
    def citation; end

    private

      def process_non_empty_file(file:)
        # Relative path is set by the jquery uploader when uploading a directory
        curation_concern.relative_path = params[:relative_path] if params[:relative_path]
        actor.create_metadata(params[:file_set])
        actor.attach_to_work(find_parent_by_id)
        if actor.create_content(file)
          response_for_successfully_processed_file
        else
          msg = curation_concern.errors.full_messages.join(', ')
          flash[:error] = msg
          json_error "Error creating file #{file.original_filename}: #{msg}"
        end
      end

      def empty_file_response(file)
        options = {
          errors: { files: "#{file.original_filename} has no content! (Zero length file)" },
          description: t('hyrax.api.unprocessable_entity.empty_file')
        }
        render_json_response(response_type: :unprocessable_entity, options: options)
      end

      def response_for_successfully_processed_file
        respond_to do |format|
          format.html do
            if request.xhr?
              render 'jq_upload', formats: 'json', content_type: 'text/html'
            else
              redirect_to [main_app, curation_concern.parent]
            end
          end
          format.json do
            render 'jq_upload', status: :created, location: polymorphic_path([main_app, curation_concern])
          end
        end
      end

      # this is provided so that implementing application can override this behavior and map params to different attributes
      def update_metadata
        file_attributes = change_set_class.model_attributes(attributes)
        actor.update_metadata(file_attributes)
      end

      def attempt_update
        if wants_to_revert?
          actor.revert_content(params[:revision])
        elsif params.key?(:file_set)
          if params[:file_set].key?(:files)
            actor.update_content(params[:file_set][:files].first)
          else
            update_metadata
          end
        end
      end

      def after_update_response
        respond_to do |wants|
          wants.html do
            redirect_to [main_app, curation_concern], notice: "The file #{view_context.link_to(curation_concern, [main_app, curation_concern])} has been updated."
          end
          wants.json do
            @presenter = show_presenter.new(curation_concern, current_ability)
            render :show, status: :ok, location: polymorphic_path([main_app, curation_concern])
          end
        end
      end

      def after_update_failure_response
        respond_to do |wants|
          wants.html do
            initialize_edit_form
            flash[:error] = "There was a problem processing your request."
            render 'edit', status: :unprocessable_entity
          end
          wants.json { render_json_response(response_type: :unprocessable_entity, options: { errors: curation_concern.errors }) }
        end
      end

      def add_breadcrumb_for_controller
        add_breadcrumb I18n.t('hyrax.dashboard.my.works'), hyrax.my_works_path
      end

      def add_breadcrumb_for_action
        case action_name
        when 'edit'.freeze
          add_breadcrumb I18n.t("hyrax.file_set.browse_view"), main_app.hyrax_file_set_path(params["id"])
        when 'show'.freeze
          add_breadcrumb presenter.parent.to_s, main_app.polymorphic_path(presenter.parent)
          add_breadcrumb presenter.to_s, main_app.polymorphic_path(presenter)
        end
      end

      # Override of Blacklight::RequestBuilders
      def search_builder_class
        Hyrax::FileSetSearchBuilder
      end

      def initialize_edit_form
        original = @file_set.original_file
        @version_list = Hyrax::VersionListPresenter.new(original ? original.versions.all : [])
        @groups = current_user.groups
      end

      def actor
        @actor ||= Hyrax::Actors::FileSetActor.new(@file_set, current_user)
      end

      def attributes
        params.fetch(:file_set, {}).except(:files).permit!.dup # use a copy of the hash so that original params stays untouched when interpret_visibility modifies things
      end

      def presenter
        @presenter ||= begin
          _, document_list = search_results(params)
          curation_concern = document_list.first
          raise CanCan::AccessDenied unless curation_concern
          show_presenter.new(curation_concern, current_ability, request)
        end
      end

      def wants_to_revert?
        params.key?(:revision) && params[:revision] != curation_concern.latest_content_version.label
      end

      # Override this method to add additional response formats to your local app
      def additional_response_formats(_); end

      def file_set_params
        params.require(:file_set).permit(
          :visibility_during_embargo, :embargo_release_date, :visibility_after_embargo, :visibility_during_lease, :lease_expiration_date, :visibility_after_lease, :visibility, title: []
        )
      end

      def empty_file?(file)
        (file.respond_to?(:tempfile) && file.tempfile.size == 0) || (file.respond_to?(:size) && file.size == 0)
      end

      # This allows us to use the unauthorized and form_permission template in hyrax/base,
      # while prefering our local paths. Thus we are unable to just override `self.local_prefixes`
      def _prefixes
        @_prefixes ||= super + ['hyrax/base']
      end

      def json_error(error, name = nil, additional_arguments = {})
        args = { error: error }
        args[:name] = name if name
        render additional_arguments.merge(json: [args])
      end
  end
end
