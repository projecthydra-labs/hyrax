# frozen_string_literal: true

Hyrax.publisher.subscribe(Hyrax::Listeners::BatchNotificationListener.new)
Hyrax.publisher.subscribe(Hyrax::Listeners::ObjectLifecycleListener.new)
Hyrax.publisher.subscribe(Hyrax::Listeners::FileSetLifecycleListener.new)
Hyrax.publisher.subscribe(Hyrax::Listeners::FileSetLifecycleNotificationListener.new)

# Publish events from old style Hyrax::Callbacks to trigger the listeners
# When callbacks are removed and replaced with direct event publication, drop these blocks
Hyrax.config.callback.set(:after_create_concern, warn: false) do |curation_concern, user|
  Hyrax.publisher.publish('object.deposited', object: curation_concern, user: user)
end

Hyrax.config.callback.set(:after_create_fileset, warn: false) do |file_set, user|
  Hyrax.publisher.publish('file.set.attached', file_set: file_set, user: user)
end

Hyrax.config.callback.set(:after_revert_content, warn: false) do |file_set, user, revision|
  Hyrax.publisher.publish('file.set.restored', file_set: file_set, user: user, revision: revision)
end

Hyrax.config.callback.set(:after_update_metadata, warn: false) do |curation_concern, user|
  Hyrax.publisher.publish('object.metadata.updated', object: curation_concern, user: user)
end

Hyrax.config.callback.set(:after_destroy, warn: false) do |id, user|
  Hyrax.publisher.publish('object.deleted', id: id, user: user)
end

Hyrax.config.callback.set(:after_fixity_check_failure, warn: false) do |file_set, checksum_audit_log:|
  Hyrax.publisher.publish('file.set.audited', file_set: file_set, audit_log: checksum_audit_log, result: :failure)
end

Hyrax.config.callback.set(:after_batch_create_success, warn: false) do |user|
  Hyrax.publisher.publish('batch.created', user: user, messages: [], result: :success)
end

Hyrax.config.callback.set(:after_batch_create_failure, warn: false) do |user, messages|
  Hyrax.publisher.publish('batch.created', user: user, messages: messages, result: :failure)
end

Hyrax.config.callback.set(:after_import_url_failure, warn: false) do |file_set, user|
  Hyrax.publisher.publish('file.set.url.imported', file_set: file_set, user: user, result: :failure)
end
