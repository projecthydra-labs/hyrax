module Hyrax
  module Admin
    class FeaturesController < Flipflop::FeaturesController
      layout 'admin'

      before_action do
        authorize! :manage, Hyrax::Feature
      end

      def index
        add_breadcrumb t(:'hyrax.controls.home'), root_path
        add_breadcrumb t(:'hyrax.toolbar.admin.menu'), hyrax.admin_path
        add_breadcrumb t(:'hyrax.admin.sidebar.settings'), hyrax.admin_features_path
        super
      end
    end
  end
end
