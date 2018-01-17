module Hyrax
  module Actors
    # If there is a key `:remote_files' in the attributes, it attaches the files at the specified URIs
    # to the work. e.g.:
    #     attributes[:remote_files] = filenames.map do |name|
    #       { url: "https://example.com/file/#{name}", file_name: name }
    #     end
    #
    # Browse everything may also return a local file. And although it's in the
    # url property, it may have spaces, and not be a valid URI.
    class CreateWithRemoteFilesActor < Hyrax::Actors::AbstractActor
      # @param [Hyrax::Actors::Environment] env
      # @return [Valkyrie::Resource,FalseClass] the saved resource if create was successful
      def create(env)
        remote_files = env.attributes.delete(:remote_files)
        saved = next_actor.create(env)
        return saved if saved && attach_files(env, remote_files)
        false
      end

      # @param [Hyrax::Actors::Environment] env
      # @return [Valkyrie::Resource,FalseClass] the saved resource if update was successful
      def update(env)
        remote_files = env.attributes.delete(:remote_files)
        saved = next_actor.update(env)
        return saved if saved && attach_files(env, remote_files)
        false
      end

      private

        def whitelisted_ingest_dirs
          Hyrax.config.whitelisted_ingest_dirs
        end

        # @param uri [URI] the uri fo the resource to import
        def validate_remote_url(uri)
          if uri.scheme == 'file'
            path = File.absolute_path(CGI.unescape(uri.path))
            whitelisted_ingest_dirs.any? do |dir|
              path.start_with?(dir) && path.length > dir.length
            end
          else
            # TODO: It might be a good idea to validate other URLs as well.
            #       The server can probably access URLs the user can't.
            true
          end
        end

        # @param [HashWithIndifferentAccess] remote_files
        # @return [TrueClass]
        def attach_files(env, remote_files)
          return true unless remote_files
          remote_files.each do |file_info|
            next if file_info.blank? || file_info[:url].blank?
            # Escape any space characters, so that this is a legal URI
            uri = URI.parse(Addressable::URI.escape(file_info[:url]))
            unless validate_remote_url(uri)
              Rails.logger.error "User #{env.user.user_key} attempted to ingest file from url #{file_info[:url]}, which doesn't pass validation"
              return false
            end
            file_set = create_file_from_url(env.user, uri, file_info[:file_name])
            Hyrax::Actors::FileSetActor.new(file_set, env.user).attach_to_work(env.curation_concern)
          end
          true
        end

        # Generic utility for creating FileSet from a URL
        # Used in to import files using URLs from a file picker like browse_everything
        # @return [FileSet] the persisted FileSet
        def create_file_from_url(user, uri, file_name)
          change_set = build_change_set(user: user,
                                        import_url: uri.to_s,
                                        label: file_name)
          file_set = nil
          change_set_persister.buffer_into_index do |buffered_changeset_persister|
            file_set = buffered_changeset_persister.save(change_set: change_set)
          end
          ingest_file_later(file_set, uri, user)

          file_set
        end

        # @param file_set [FileSet] the persisted FileSet
        # @param uri [URI] the path to the file
        # @param user [User] the user who is doing the import
        # @return [Void]
        def ingest_file_later(file_set, uri, user)
          if uri.scheme == 'file'
            # Turn any %20 into spaces.
            file_path = CGI.unescape(uri.path)
            IngestLocalFileJob.perform_later(file_set, file_path, user)
          else
            # TODO: should we just pass the uri?
            ImportUrlJob.perform_later(file_set, operation_for(user: user))
          end
        end

        def build_change_set(attributes)
          Hyrax::FileSetChangeSet.new(::FileSet.new, attributes).tap(&:sync)
        end

        def change_set_persister
          Hyrax::FileSetChangeSetPersister.new(
            metadata_adapter: metadata_adapter,
            storage_adapter: Valkyrie.config.storage_adapter
          )
        end

        def metadata_adapter
          Valkyrie::MetadataAdapter.find(:indexing_persister)
        end

        def operation_for(user:)
          Hyrax::Operation.create!(user: user,
                                   operation_type: "Attach Remote File")
        end
    end
  end
end
