require 'select2-rails'
require 'nest'
require 'redis-namespace'
require 'mailboxer'
require 'carrierwave'
require 'rails_autolink'
require 'font-awesome-rails'
require 'tinymce-rails'
require 'blacklight'
require 'blacklight/gallery'
require 'noid-rails'
require 'hydra/head'
require 'hydra-editor'
require 'browse-everything'
require 'hydra/works'
require 'hyrax/engine'
require 'hyrax/version'
require 'hyrax/inflections'
require 'kaminari_route_prefix'

module Hyrax
  extend ActiveSupport::Autoload

  eager_autoload do
    autoload :Arkivo
    autoload :Collections
    autoload :Configuration
    autoload :ControlledVocabularies
    autoload :RedisEventStore
    autoload :ResourceSync
    autoload :Zotero
  end

  # @api public
  #
  # Exposes the Hyrax configuration
  #
  # @yield [Hyrax::Configuration] if a block is passed
  # @return [Hyrax::Configuration]
  # @see Hyrax::Configuration for configuration options
  def self.config(&block)
    @config ||= Hyrax::Configuration.new

    yield @config if block

    @config
  end

  ##
  # @return [Logger]
  def self.logger
    @logger ||= Valkyrie.logger
  end

  def self.primary_work_type
    config.curation_concerns.first
  end

  def self.persister
    metadata_adapter.persister
  end

  def self.metadata_adapter
    Valkyrie.config.metadata_adapter
  end

  def self.storage_adapter
    Valkyrie.config.storage_adapter
  end

  def self.query_service
    metadata_adapter.query_service
  end
end
