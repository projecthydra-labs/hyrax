module Hyrax
  module Actors
    class ApplyOrderActor < AbstractActor
      # @param [Hyrax::Actors::Environment] env
      # @return [Boolean] true if update was successful
      def update(env)
        ordered_member_ids = env.attributes.delete(:ordered_member_ids)
        sync_members(env, ordered_member_ids) &&
          apply_order(env.curation_concern, ordered_member_ids) &&
          next_actor.update(env)
      end

      private

        def can_edit_both_works?(env, work)
          env.current_ability.can?(:edit, work) && env.current_ability.can?(:edit, env.curation_concern)
        end

        def sync_members(env, ordered_member_ids)
          return true if ordered_member_ids.nil?
          cleanup_ids_to_remove_from_curation_concern(env.curation_concern, ordered_member_ids)
          add_new_work_ids_not_already_in_curation_concern(env, ordered_member_ids)
          env.curation_concern.errors[:ordered_member_ids].empty?
        end

        # @todo Why is this not doing work.save?
        # @see Hyrax::Actors::AddToWorkActor for duplication
        def cleanup_ids_to_remove_from_curation_concern(curation_concern, ordered_member_ids)
          (curation_concern.ordered_member_ids - ordered_member_ids).each do |old_id|
            curation_concern.member_ids.delete(old_id)
          end
        end

        def add_new_work_ids_not_already_in_curation_concern(env, ordered_member_ids)
          (ordered_member_ids - env.curation_concern.ordered_member_ids).each do |work_id|
            work = find_resource(work_id)
            if can_edit_both_works?(env, work)
              env.curation_concern.member_ids += [work_id]
              persister.save(resource: env.curation_concern)
            else
              env.curation_concern.errors[:ordered_member_ids] << "Works can only be related to each other if user has ability to edit both."
            end
          end
        end

        def apply_order(curation_concern, new_order)
          return true unless new_order
          curation_concern.ordered_member_proxies.each_with_index do |proxy, index|
            unless new_order[index]
              proxy.prev.next = curation_concern.ordered_member_proxies.last.next
              break
            end
            proxy.proxy_for = ActiveFedora::Base.id_to_uri(new_order[index])
            proxy.target = nil
          end
          curation_concern.list_source.order_will_change!
          true
        end

        def find_resource(id)
          query_service.find_by(id: Valkyrie::ID.new(id.to_s))
        end

        delegate :query_service, :persister, to: :indexing_adapter

        def indexing_adapter
          @indexing_adapter ||= Valkyrie::MetadataAdapter.find(:indexing_persister)
        end
    end
  end
end
