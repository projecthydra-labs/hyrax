module Hyrax
  module SolrDocument
    module Metadata
      extend ActiveSupport::Concern
      class_methods do
        def attribute(name, type, field)
          define_method name do
            type.coerce(self[field])
          end
        end

        def solr_name(*args)
          Solrizer.solr_name(*args)
        end
      end

      module Solr
        class Array
          # @return [Array]
          def self.coerce(input)
            ::Array.wrap(input)
          end
        end

        class String
          # @return [String]
          def self.coerce(input)
            ::Array.wrap(input).first.to_s
          end
        end

        class Date
          # @return [Date]
          def self.coerce(input)
            field = String.coerce(input)
            return if field.blank?
            begin
              ::Date.parse(field)
            rescue ArgumentError
              Rails.logger.info "Unable to parse date: #{field.first.inspect}"
            end
          end
        end

        class Boolean
          # @return [Boolean]
          def self.coerce(input)
            field = String.coerce(input)
            return if field.blank?
            field == 'true'
          end
        end
      end

      # How should we be doing this? Ex: There is already a conversion that happens if using the ORMConverter:
      # https://github.com/samvera-labs/valkyrie/blob/82c2dac448ad57b5693ee218172b8e34ed07b19a/lib/valkyrie/persistence/solr/orm_converter.rb#L39
      module Valkyrie
        class Id
          # @return [Id]
          def self.coerce(input)
            field = ::Array.wrap(input).first.to_s
            field.blank? ? nil : field.sub(/^id-/, '')
          end
        end
      end

      included do
        attribute :identifier, Solr::Array, solr_name('identifier')
        attribute :based_near, Solr::Array, solr_name('based_near')
        attribute :based_near_label, Solr::Array, solr_name('based_near_label')
        attribute :related_url, Solr::Array, solr_name('related_url')
        attribute :resource_type, Solr::Array, solr_name('resource_type')
        attribute :edit_groups, Solr::Array, ::Ability.edit_group_field
        attribute :edit_people, Solr::Array, ::Ability.edit_user_field
        attribute :read_groups, Solr::Array, ::Ability.read_group_field
        attribute :collection_ids, Solr::Array, 'collection_ids_tesim'
        attribute :admin_set, Solr::Array, solr_name('admin_set')
        attribute :member_of_collection_ids, Solr::Array, solr_name('member_of_collection_ids', :symbol)
        attribute :member_ids, Solr::Array, ::Valkyrie::Persistence::Solr::Queries::MEMBER_IDS
        attribute :description, Solr::Array, solr_name('description')
        attribute :title, Solr::Array, solr_name('title')
        attribute :contributor, Solr::Array, solr_name('contributor')
        attribute :creator, Solr::Array, solr_name('creator')
        attribute :subject, Solr::Array, solr_name('subject')
        attribute :publisher, Solr::Array, solr_name('publisher')
        attribute :language, Solr::Array, solr_name('language')
        attribute :keyword, Solr::Array, solr_name('keyword')
        attribute :license, Solr::Array, solr_name('license')
        attribute :source, Solr::Array, solr_name('source')
        attribute :date_created, Solr::Array, solr_name('date_created')
        attribute :rights_statement, Solr::Array, solr_name('rights_statement')

        attribute :mime_type, Solr::String, solr_name('mime_type', :symbol)
        attribute :workflow_state, Solr::String, solr_name('workflow_state_name', :symbol)
        attribute :human_readable_type, Solr::String, solr_name('human_readable_type', :stored_searchable)
        attribute :representative_id, Valkyrie::Id, solr_name('representative_id', :symbol)
        attribute :thumbnail_id, Solr::String, solr_name('hasRelatedImage', :symbol)
        attribute :thumbnail_path, Solr::String, CatalogController.blacklight_config.index.thumbnail_field
        attribute :label, Solr::String, solr_name('label')
        attribute :file_format, Solr::String, Hyrax::IndexMimeType.file_format_field
        attribute :suppressed?, Solr::Boolean, solr_name('suppressed', Solrizer::Descriptor.new(:boolean, :stored, :indexed))

        attribute :date_modified, Solr::Date, solr_name('date_modified', :stored_sortable, type: :date)
        attribute :date_uploaded, Solr::Date, solr_name('date_uploaded', :stored_sortable, type: :date)
        attribute :create_date, Solr::Date, solr_name('created_at', :stored_sortable, type: :date)
        attribute :embargo_release_date, Solr::Date, Hydra.config.permissions.embargo.release_date
        attribute :lease_expiration_date, Solr::Date, Hydra.config.permissions.lease.expiration_date
      end
    end
  end
end
