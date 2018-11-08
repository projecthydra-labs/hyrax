module Hyrax
  module Actors
    # When adding member FileSets to a Work, Hyrax saves
    #   and reloads the work for each new member FileSet.
    #   This can significantly slow down ingest for Works
    #   with many member FileSets. The saving and reloading
    #   happens in FileSetActor#attach_to_work.
    #
    # This is a 'swappable' alternative approach. It will
    #   be of most value to Hyrax applications dealing with
    #   works with many filesets. Anecdotally, a work with
    #   600 filesets can be processed in ~15 mins versus
    #   > 3 hours with the standard approach.
    #
    # The tradeoff is that the ordered members are now added in a
    #   single step after the creation of all the FileSets, thus
    #   introducing a slight risk of orphan filesets if the upload
    #   fails before the addition of the ordered members. This
    #   has not been observed in practice.
    #
    # Swapping out the actors can be achieved thus:
    #
    # In `config/initializers/hyrax.rb`:
    # ```
    # Hyrax::CurationConcern.actor_factory.swap(Hyrax::Actors::CreateWithFilesActor,
    #   Hyrax::Actors::CreateWithFilesOrderedMembersActor)
    # ```
    # Alternatively, in `config/application.rb`:
    # ```
    # config.to_prepare
    #   Hyrax::CurationConcern.actor_factory.swap(Hyrax::Actors::CreateWithFilesActor,
    #     Hyrax::Actors::CreateWithFilesOrderedMembersActor)
    # end
    # ```
    # Creates a work and attaches files to the work
    class CreateWithFilesOrderedMembersActor < CreateWithFilesActor
      # @return [TrueClass]
      def attach_files(files, env)
        return true if files.blank?
        AttachFilesToWorkWithOrderedMembersJob.perform_later(env.curation_concern, files, env.attributes.to_h.symbolize_keys)
        true
      end
    end
  end
end
