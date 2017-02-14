# Create a single work in the background
# Used by the BatchCreateJob
class CreateWorkJob < ActiveJob::Base
  queue_as Hyrax.config.ingest_queue_name

  before_enqueue do |job|
    log = job.arguments.last
    log.pending_job(self)
  end

  # This copies metadata from the passed in attribute to all of the works that
  # are members of the given upload set
  # @param [User] user
  # @param [String] model
  # @param [Hash] attributes
  # @param [BatchCreateOperation] log
  def perform(user, model, attributes, log)
    log.performing!
    work = model.constantize.new
    actor = work_actor(work, user)
    status = actor.create(attributes)
    return log.success! if status
    log.fail!(work.errors.full_messages.join(' '))
  end

  private

    def work_actor(work, user)
      Hyrax::CurationConcern.actor(work, ability(user))
    end

    def ability(user)
      Ability.new(user)
    end
end
