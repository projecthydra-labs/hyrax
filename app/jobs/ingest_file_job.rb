class IngestFileJob < Hyrax::ApplicationJob
  queue_as Hyrax.config.ingest_queue_name

  # @param [FileSet] file_set
  # @param [String] filepath the cached file within the Hyrax.config.working_path
  # @param [User] user
  # @option opts [String] mime_type
  # @option opts [String] filename
  # @option opts [String] relation, ex. :original_file
  def perform(file_set, filepath, user, opts = {})
    relation = opts.fetch(:relation, :original_file).to_sym

    logger.debug("Performing ingest of \"#{filepath}\" with options: #{opts.inspect}")
    # Wrap in an IO decorator to attach passed-in options
    local_file = Hydra::Derivatives::IoDecorator.new(File.open(filepath, "rb"))
    local_file.mime_type = opts.fetch(:mime_type, nil)
    local_file.original_name = opts.fetch(:filename, File.basename(filepath))

    # Tell AddFileToFileSet service to skip versioning because versions will be minted by
    # VersionCommitter when necessary during save_characterize_and_record_committer.
    Hydra::Works::AddFileToFileSet.call(file_set,
                                        local_file,
                                        relation,
                                        versioning: false)

    # Persist changes to the file_set
    file_set.save!

    repository_file = file_set.send(relation)

    # Do post file ingest actions
    Hyrax::VersioningService.create(repository_file, user)

    # In another worker, characterize the uploaded file.
    CharacterizeJob.perform_later(file_set, repository_file.id, filepath)
  end
end
