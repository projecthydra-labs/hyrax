# frozen_string_literal: true
module Hyrax
  # Presents a list of works in workflow
  class Admin::WorkflowsController < ApplicationController
    before_action :ensure_authorized!
    with_themed_layout 'dashboard'
    class_attribute :deposited_workflow_state_name

    # Works that are in this workflow state (see workflow json template) are excluded from the
    # status list and display in the "Published" tab
    self.deposited_workflow_state_name = 'deposited'

    def index
      add_breadcrumb t(:'hyrax.controls.home'), root_path
      add_breadcrumb t(:'hyrax.dashboard.breadcrumbs.admin'), hyrax.dashboard_path
      add_breadcrumb t(:'hyrax.admin.sidebar.tasks'), '#'
      add_breadcrumb t(:'hyrax.admin.sidebar.workflow_review'), request.path
      @status_list = Hyrax::Workflow::StatusListService.new(current_user, "-workflow_state_name_ssim:#{deposited_workflow_state_name}")
      @published_list = Hyrax::Workflow::StatusListService.new(current_user, "workflow_state_name_ssim:#{deposited_workflow_state_name}")
      # @status_list = actionable_objects.reject(&:published?)
      # @published_list = actionable_objects.select(&:published?)
    end

    private

    def ensure_authorized!
      authorize! :review, :submissions
    end

    def actionable_objects
      @actionable_objects ||=
        Hyrax::Workflow::ActionableObjects.new(user: current_user)
    end
  end
end
