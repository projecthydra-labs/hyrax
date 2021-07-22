# frozen_string_literal: true
module Hyrax
  # Presents the options for the AdminSet widget on the create/edit form
  class AdminSetOptionsPresenter
    ##
    # @param [Hyrax::AdminSetService] service
    def initialize(service, current_ability: service.context.current_ability)
      @service = service
      @current_ability = current_ability
    end

    # Return AdminSet selectbox options based on access type
    #
    # @todo this hits the Solr from the view. it would be better to avoid this.
    #
    # @param [Symbol] access :deposit, :read, or :edit
    def select_options(access = :deposit)
      @service.search_results(access).map do |admin_set|
        [admin_set.to_s, admin_set.id, data_attributes(admin_set)]
      end
    end

    private

    # Create a hash of HTML5 'data' attributes. These attributes are added to select_options and
    # later utilized by Javascript to limit new Work options based on AdminSet selected
    def data_attributes(admin_set)
      # Get permission template associated with this AdminSet (if any)
      permission_template = PermissionTemplate.find_by(source_id: admin_set.id)

      # Only add data attributes if permission template exists
      return {} unless permission_template
      attributes_for(permission_template: permission_template)
    end

    # all PermissionTemplate release & visibility data attributes (if not blank or false)
    def attributes_for(permission_template:)
      {}.tap do |attrs|
        attrs['data-sharing'] = sharing?(permission_template: permission_template)
        # Either add "no-delay" (if immediate release) or a specific release date, but not both.
        if permission_template.release_no_delay?
          attrs['data-release-no-delay'] = true
        elsif permission_template.release_date.present?
          attrs['data-release-date'] = permission_template.release_date
        end
        attrs['data-release-before-date'] = true if permission_template.release_before_date?
        attrs['data-visibility'] = permission_template.visibility if permission_template.visibility.present?
      end
    end

    # Does the workflow for the currently selected permission template allow sharing?
    def sharing?(permission_template:)
      # This short-circuit builds on a stated "promise" in the UI of
      # editing an admin set:
      #
      # > Managers of this administrative set can edit the set
      # > metadata, participants, and release and visibility
      # > settings. Managers can also edit work metadata, add to or
      # > remove files from a work, and add new works to the set.
      return true if @current_ability.can?(:manage, permission_template)

      # Otherwise, we check if the active workflow allows access grants
      !!permission_template.active_workflow&.allows_access_grant?
    end
  end
end
