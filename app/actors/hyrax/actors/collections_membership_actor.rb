module Hyrax
  module Actors
    # Adds membership to and removes membership from collections.
    # This decodes parameters that follow the rails nested parameters conventions:
    # e.g.
    #   'member_of_collections_attributes' => {
    #     '0' => { 'id' = '12312412'},
    #     '1' => { 'id' = '99981228', '_destroy' => 'true' }
    #   }
    #
    class CollectionsMembershipActor < AbstractActor
      # @param [Hyrax::Actors::Environment] env
      # @return [Boolean] true if create was successful
      def create(env)
        attributes_collection = env.attributes.delete(:member_of_collections_attributes)
        extract_collection_id(env, attributes_collection)
        assign_nested_attributes_for_collection(env, attributes_collection) &&
          next_actor.create(env)
      end

      # @param [Hyrax::Actors::Environment] env
      # @return [Boolean] true if update was successful
      def update(env)
        attributes_collection = env.attributes.delete(:member_of_collections_attributes)
        assign_nested_attributes_for_collection(env, attributes_collection) &&
          next_actor.update(env)
      end

      private

        # Attaches any unattached members.  Deletes those that are marked _delete
        # @param [Hash<Hash>] a collection of members
        def assign_nested_attributes_for_collection(env, attributes_collection)
          return true unless attributes_collection
          return false unless valid_membership?(env, attributes_collection)

          attributes_collection = attributes_collection.sort_by { |i, _| i.to_i }.map { |_, attributes| attributes }
          # checking for existing works to avoid rewriting/loading works that are
          # already attached
          existing_collections = env.curation_concern.member_of_collection_ids
          attributes_collection.each do |attributes|
            next if attributes['id'].blank?
            if existing_collections.include?(attributes['id'])
              remove(env.curation_concern, attributes['id']) if has_destroy_flag?(attributes)
            else
              add(env, attributes['id'])
            end
          end
        end

        # Adds the item to the ordered members so that it displays in the items
        # along side the FileSets on the show page
        def add(env, id)
          collection = Collection.find(id)
          return unless env.current_ability.can?(:deposit, collection)
          env.curation_concern.member_of_collections << collection
        end

        # Remove the object from the members set and the ordered members list
        def remove(curation_concern, id)
          collection = Collection.find(id)
          curation_concern.member_of_collections.delete(collection)
        end

        # Determines if a hash contains a truthy _destroy key.
        # rubocop:disable Naming/PredicateName
        def has_destroy_flag?(hash)
          ActiveFedora::Type::Boolean.new.cast(hash['_destroy'])
        end
        # rubocop:enable Naming/PredicateName

        # Extact a singleton collection id from the collection attributes and save it in env.  Later in the actor stack,
        # in apply_permission_template_actor.rb, `env.attributes[:collection_id]` will be used to apply the
        # permissions of the collection to the created work.  With one and only one collection, the work is seen as
        # being created directly in that collection.  The permissions will not be applied to the work if the collection
        # type is configured not to allow that or if the work is being created in more than one collection.
        #
        # @param [Hash] attributes_collection which was extracted from env[:member_of_collections_attributes] in create().
        # e.g.
        #   'attributes_collection' => {
        #     '0' => { 'id' = '12312412'},
        #   }
        #
        # Given an array of collection_attributes when it is size:
        # * 0 do not set `env.attributes[:collection_id]`
        # * 1 set `env.attributes[:collection_id]` to the one and only one collection
        # * 2+ do not set `env.attributes[:collection_id]`
        #
        # NOTE: Only called from create.  All collections are being added as parents of a work.  None are being removed.
        def extract_collection_id(env, attributes_collection)
          # Determine if the work is being created in one and only one collection.
          return unless attributes_collection && attributes_collection.size == 1

          # Extract the collection id from attributes_collection,
          collection_id = attributes_collection.first.second['id']

          # Do not apply permissions to work if collection type is configured not to
          collection = ::Collection.find(collection_id)
          return unless collection.share_applies_to_new_works?

          # Save the collection id in env for use in apply_permission_template_actor
          env.attributes[:collection_id] = collection_id
        end

        def valid_membership?(env, attributes_collection)
          collection_ids = attributes_collection.map { |_, attributes| attributes['id'] }
          multiple_memberships = Hyrax::MultipleMembershipChecker.new(item: env.curation_concern).check(collection_ids: collection_ids)
          if multiple_memberships
            env.curation_concern.errors.add(:collections, multiple_memberships)
            return false
          end
          true
        end
    end
  end
end
