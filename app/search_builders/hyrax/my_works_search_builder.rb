# Added to allow for the My controller to show only things I have edit access to
class Hyrax::MyWorksSearchBuilder < Hyrax::SearchBuilder
  include Hyrax::FilterByType

  self.default_processor_chain += [:show_only_resources_deposited_by_current_user]

  # We remove the access controls filter, because some of the works a user has
  # deposited may have gone through a workflow which has removed their ability
  # to edit the work.
  self.default_processor_chain -= [:add_access_controls_to_solr_params]

  def only_works?
    true
  end
end
