module Hyrax
  module Actors
    # Responsible for "applying" the various edit and read attributes to the given curation concern.
    # @see Hyrax::AdminSetService for release_date interaction
    class ApplyPermissionTemplateActor < Hyrax::Actors::AbstractActor
      # @param [Hyrax::Actors::Environment] env
      # @return [Boolean] true if create was successful
      def create(env)
        add_edit_users(env)
        next_actor.create(env)
      end

      private

        def add_edit_users(env)
          return if env.attributes[:admin_set_id].blank?
          template = Hyrax::PermissionTemplate.find_by!(admin_set_id: env.attributes[:admin_set_id].to_s)
          env.curation_concern.edit_users += template.agent_ids_for(agent_type: 'user', access: 'manage')
          env.curation_concern.edit_groups += template.agent_ids_for(agent_type: 'group', access: 'manage')
          env.curation_concern.read_users += template.agent_ids_for(agent_type: 'user', access: 'view')
          env.curation_concern.read_groups += template.agent_ids_for(agent_type: 'group', access: 'view')
        end
    end
  end
end
