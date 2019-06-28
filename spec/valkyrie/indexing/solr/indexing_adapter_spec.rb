# frozen_string_literal: true
require 'spec_helper'
require 'valkyrie/indexing/solr/indexing_adapter'

RSpec.describe Valkyrie::Indexing::Solr::IndexingAdapter, :clean_index do
  subject(:adapter) { described_class.new }
  let(:persister) { Wings::Valkyrie::Persister.new(adapter: metadata_adapter) }
  let(:metadata_adapter) { Wings::Valkyrie::MetadataAdapter.new }
  let(:resource) { FactoryBot.create_for_repository(:hyrax_resource) }
  let(:resource2) { FactoryBot.create_for_repository(:hyrax_resource) }

  describe "#connection" do
    it "returns connection" do
      expect(adapter.connection.uri.to_s).to include 'valkyrie-test'
    end
  end

  it "can save a resource" do
    adapter.save(resource: resource)
    expect(Hyrax::SolrService.query("*:*", use_valkyrie: true).map(&:id)).to eq [resource.id.to_s]
  end

  it "can save multiple resources at once" do
    adapter.save_all(resources: [resource, resource2])
    expect(Hyrax::SolrService.query("*:*", use_valkyrie: true).map(&:id)).to contain_exactly resource.id.to_s, resource2.id.to_s
  end

  it "can delete an object" do
    adapter.save(resource: resource)
    expect(Hyrax::SolrService.query("*:*", use_valkyrie: true).count).to eq 1
    adapter.delete(resource: resource)
    expect(Hyrax::SolrService.query("*:*", use_valkyrie: true).count).to eq 0
  end

  it "can delete all objects" do
    adapter.save_all(resources: [resource, resource2])
    expect(Hyrax::SolrService.query("*:*", use_valkyrie: true).count).to eq 2
    adapter.wipe!
    expect(Hyrax::SolrService.query("*:*", use_valkyrie: true).count).to eq 0
  end
end
