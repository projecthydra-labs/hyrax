class FixityCheckJob < ActiveJob::Base
  # URI of the resource to check fixity for.
  # This URI could include the actual resource (e.g. content) and the version to fixity check:
  #     http://localhost:8983/fedora/rest/test/a/b/c/abcxyz/content/fcr:versions/version1
  # but it could also just be:
  #     http://localhost:8983/fedora/rest/test/a/b/c/abcxyz/content
  # @param [FileSet] file_set - the parent object
  # @param [String] file_id - used to find the file within its parent object (usually "original_file")
  # @param [String] uri - of the specific file/version to fixity check
  def perform(file_set, file_id, uri)
    log = run_check(file_set, file_id, uri)
    fixity_ok = log.pass == 1
    unless fixity_ok
      if Hyrax.config.callback.set?(:after_fixity_check_failure)
        login = file_set.depositor
        user = User.find_by_user_key(login)
        Hyrax.config.callback.run(:after_fixity_check_failure, file_set, user, log.created_at)
      end
    end
    fixity_ok
  end

  protected

    def run_check(file_set, file_id, uri)
      begin
        fixity_ok = ActiveFedora::FixityService.new(uri).check
      rescue Ldp::NotFound
        error_msg = 'resource not found'
      end

      if fixity_ok
        passing = 1
        ChecksumAuditLog.prune_history(file_set.id, file_id)
      else
        logger.warn "***AUDIT*** Audit failed for #{uri} #{error_msg}"
        passing = 0
      end
      ChecksumAuditLog.create!(pass: passing, file_set_id: file_set.id, version: uri, file_id: file_id)
    end

  private

    def logger
      ActiveFedora::Base.logger
    end
end
