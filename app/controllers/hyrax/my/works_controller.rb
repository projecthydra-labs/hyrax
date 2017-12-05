module Hyrax
  module My
    class WorksController < MyController
      class_attribute :create_work_presenter_class
      self.create_work_presenter_class = Hyrax::SelectTypeListPresenter

      # Search builder for a list of works that belong to me
      # Override of Blacklight::RequestBuilders
      def search_builder_class
        Hyrax::My::WorksSearchBuilder
      end

      def index
        add_breadcrumb t(:'hyrax.controls.home'), root_path
        add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
        add_breadcrumb t(:'hyrax.admin.sidebar.works'), hyrax.my_works_path
        @create_work_presenter = create_work_presenter_class.new(current_user)
        super
      end

      private

        def search_action_url(*args)
          hyrax.my_works_url(*args)
        end

        # The url of the "more" link for additional facet values
        def search_facet_path(args = {})
          hyrax.my_dashboard_works_facet_path(args[:id])
        end
    end
  end
end
