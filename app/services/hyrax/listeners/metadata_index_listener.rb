# frozen_string_literal: true

module Hyrax
  module Listeners
    ##
    # Reindexes resources when their metadata is updated.
    #
    # @note This listener makes no attempt to avoid reindexing when no metadata
    #   has actually changed, or when real metadata changes won't impact the
    #   indexed data. We trust that published metadata update events represent
    #   actual changes to object metadata, and that the indexing adapter
    #   optimizes reasonably for actual index document contents.
    class MetadataIndexListener
      ##
      # Re-index the resource.
      #
      # @param event [Dry::Event]
      def on_object_metadata_updated(event)
        Hyrax.index_adapter.save(resource: event[:object])
      end
    end
  end
end
