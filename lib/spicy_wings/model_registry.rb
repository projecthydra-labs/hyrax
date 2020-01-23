# frozen_string_literal: true

module SpicyWings
  ##
  # This registry provides an off-ramp for legacy ActiveFedora models.
  #
  # New valkyrie models can be defined manually and registered as an analogue
  # of an existing `ActiveFedora::Base` implementer. This allows SpicyWings to cast
  # the new model to the legacy model when saving, ensuring backwards compatible
  # data on save.
  #
  # Several models from Hyrax components have default mappings provided by SpicyWings.
  #
  # @example
  #   SpicyWings::ModelRegistry.register(NewValkyrieModel, OldActiveFedoraModel)
  #
  #   SpicyWings::ModelRegistry.lookup(NewValkyrieModel) # => OldActiveFedoraModel
  #   SpicyWings::ModelRegistry.reverse_lookup(OldActiveFedoraModel) # => NewValkyrieModel
  #
  class ModelRegistry
    include Singleton

    def self.register(*args)
      instance.register(*args)
    end

    def self.lookup(*args)
      instance.lookup(*args)
    end

    def self.reverse_lookup(*args)
      instance.reverse_lookup(*args)
    end

    def initialize
      @map = {}
    end

    def register(valkyrie, active_fedora)
      @map[valkyrie] = active_fedora
    end

    def lookup(valkyrie)
      @map[valkyrie]
    end

    def reverse_lookup(active_fedora)
      @map.rassoc(active_fedora)&.first
    end
  end
end
