# frozen_string_literal: true
module Hyrax
  ##
  # @api public
  # @since 3.1.0
  #
  # Presents select options for admin sets.
  #
  # Each entry in the {#select_options} return value provides a label for
  # display, an id to serve as the value, and a data hash which is used as HTML5
  # data entries. The data entries can be used as hooks for Javascript
  # to control input validation taking into account the Admin Set and
  # `PermissionTemplate` rules (`visibility_component.es6` does this, for
  # example).
  #
  # @note this supersedes the older +Hyrax::AdminSetOptionsPresenter+, which
  #   actied more like a "service" sending database queries to Solr and
  #   ActiveRecord.  this version seeks only to present the input data and
  #   relies on its caller to pass in the right data.
  class AdminSetSelectionPresenter
    ##
    # @param [Array<#id>]
    def initialize(admin_sets:)
      @admin_sets = admin_sets
    end

    ##
    # @return [Array<Array<String, String, Hash>>] an array suitable for  a form
    #   input `collection:` parameter. it should contain a label, an id, and a
    #   hash of HTML5  data attributes.
    def select_options
      @admin_sets.map do |admin_set|
        case admin_set
        when OptionsEntry
          admin_set.result
        else
          OptionsEntry.new(admin_set: admin_set).result
        end
      end
    end

    ##
    # @api public
    class OptionsEntry
      ##
      # @!attribute [rw] admin_set
      #   @return [AdministrativeSet, SolrDocument]
      # @!attribute [rw] permission_template
      #   @return [PermissionTemplate]
      # @!attribute [rw] permit_sharing
      #   @return [Boolean]
      attr_accessor :admin_set, :permission_template, :permit_sharing

      ##
      # @param [AdministrativeSet, SolrDocument] admin_set
      # @param [PermissionTemplate] permission_template
      # @param [Boolean] permit_sharing
      def initialize(admin_set:, permission_template: nil, permit_sharing: false)
        @admin_set = admin_set
        @permission_template = permission_template
        @permit_sharing = permit_sharing
      end

      ##
      # @return [Array<String, String, Hash>]
      def result
        [label, id, data]
      end

      ##
      # @return [String]
      def label
        Array(admin_set.title).first || admin_set.to_s
      end

      ##
      # @return [String]
      def id
        admin_set.id.to_s
      end

      ##
      # @return [Hash{String => Object}]
      def data
        {}.tap do |data|
          data['data-sharing'] = permit_sharing

          if permission_template
            data.merge!(data_for(permission_template))
          else
            data['data-release-no-delay'] = true
          end
        end
      end

      private

      ##
      # @api private
      def data_for(template)
        {}.tap do |data|
          if template.release_no_delay?
            data['data-release-no-delay'] = true
          elsif template.release_date.present?
            data['data-release-date'] = template.release_date
          end

          data['data-release-before-date'] = true if
            template.release_before_date?
          data['data-visibility'] = template.visibility if
            template.visibility.present?
        end
      end
    end
  end
end
