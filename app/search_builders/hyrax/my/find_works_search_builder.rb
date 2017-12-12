# Search for possible works that user can edit and could be a work's child or parent.
class Hyrax::My::FindWorksSearchBuilder < Hyrax::My::SearchBuilder
  include Hyrax::FilterByType

  self.default_processor_chain += [:filter_on_title, :show_only_other_works, :show_only_works_not_child, :show_only_works_not_parent]

  # Excludes the id that is part of the params
  def initialize(context)
    super(context)
    # Without an id this class will produce an invalid query.
    @id = context.params[:id] || raise("missing required parameter: id")
    @q = context.params[:q]
  end

  def filter_on_title(solr_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] += ["_query_:\"{!field f=title_tesim}#{@q}\""]
  end

  def show_only_other_works(solr_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq] += ["-{!field f=id}#{@id}"]
  end

  def show_only_works_not_child(solr_parameters)
    solr = Valkyrie::MetadataAdapter.find(:index_solr).connection
    results = solr.get('select', params: { q: "{!field f=id}#{@id}",
                                           fl: 'member_ids_ssim',
                                           rows: 10_000,
                                           qt: 'standard' })
    ids = results['response']['docs'].flat_map { |x| x.fetch('member_ids_ssim', []) }
    return if ids.empty?
    solr_parameters[:fq] ||= []
    solr_parameters[:fq]  += ["-{!terms f=id}#{ids.join(',')}"]
  end

  def show_only_works_not_parent(solr_parameters)
    solr_parameters[:fq] ||= []
    solr_parameters[:fq]  += ["-_query_:\"{!field f=member_ids_ssim}id-#{@id}\""]
  end

  def only_works?
    true
  end
end
