# frozen_string_literal: true

RSpec.describe Hyrax::Listeners::MetadataIndexListener do
  subject(:listener) { described_class.new }
  let(:data)         { { object: resource } }
  let(:event)        { Dry::Events::Event.new(event_type, data) }
  let(:fake_adapter) { FakeIndexingAdapter.new }
  let(:resource)     { FactoryBot.valkyrie_create(:hyrax_resource) }

  # the listener should always use the currently configured Hyrax Index Adapter
  before do
    allow(Hyrax).to receive(:index_adapter).and_return(fake_adapter)
  end

  describe '#on_object_metadata_updated' do
    let(:event_type) { :on_object_metadata_updated }

    it 'reindexes the object on the configured adapter' do
      expect { listener.on_object_metadata_updated(event) }
        .to change { fake_adapter.saved_resources }
        .to contain_exactly(resource)
    end
  end
end
