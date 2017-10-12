# frozen_string_literal: true

module Hyrax
  class ChangeSetPersister
    def self.new(metadata_adapter:, storage_adapter:)
      Basic.new(metadata_adapter: metadata_adapter,
                storage_adapter: storage_adapter)
    end
  end

  class Basic
    attr_reader :metadata_adapter, :storage_adapter
    delegate :persister, :query_service, to: :metadata_adapter
    def initialize(metadata_adapter:, storage_adapter:)
      @metadata_adapter = metadata_adapter
      @storage_adapter = storage_adapter
    end

    def save(change_set:)
      persister.save(resource: change_set.resource)
    end

    def delete(change_set:)
      persister.delete(resource: change_set.resource)
    end

    def save_all(change_sets:)
      change_sets.map do |change_set|
        save(change_set: change_set)
      end
    end

    def buffer_into_index
      metadata_adapter.persister.buffer_into_index do |buffered_adapter|
        with(metadata_adapter: buffered_adapter) do |buffered_changeset_persister|
          yield(buffered_changeset_persister)
        end
      end
    end

    def with(metadata_adapter:)
      yield self.class.new(metadata_adapter: metadata_adapter, storage_adapter: storage_adapter)
    end
  end
end
