# frozen_string_literal: true

RSpec.describe Hyrax::WorksControllerBehavior, :clean_repo, type: :controller do
  let(:paths) { Rails.application.routes.url_helpers }
  let(:title) { ['Comet in Moominland'] }
  let(:work)  { FactoryBot.valkyrie_create(:hyrax_work, alternate_ids: [id], title: title) }
  let(:id)    { '123' }

  before(:context) { Hyrax.config.register_curation_concern(Hyrax::Test::SimpleWork) }

  after(:context) do
    config = Hyrax.config
    types  = config.registered_curation_concern_types - ["Hyrax::Test::SimpleWork"]

    Hyrax.config.instance_variable_set(:@registered_concerns, types)
  end

  controller(ApplicationController) do
    include Hyrax::WorksControllerBehavior

    self.curation_concern_type = Hyrax::Test::SimpleWork
    self.search_builder_class  = Hyrax::Test::SimpleWorkSearchBuilder
  end

  shared_context 'with a logged in user' do
    let(:user) { create(:user) }

    before { sign_in user }
  end

  describe '#create' do
    it 'redirects to new user login' do
      get :create, params: {}

      expect(response).to redirect_to paths.new_user_session_path(locale: :en)
    end

    xcontext 'with a logged in user' do
      include_context 'with a logged in user'

      it 'is successful' do
        get :create, params: {}

        expect(response).to be_successful
      end
    end
  end

  describe '#edit' do
    it 'gives a 404 for a missing object' do
      expect { get :edit, params: { id: 'missing_id' } }
        .to raise_error Hyrax::ObjectNotFoundError
    end

    it 'redirects to new user login' do
      get :edit, params: { id: work.id }

      expect(response).to redirect_to paths.new_user_session_path(locale: :en)
    end

    context 'with a logged in user' do
      include_context 'with a logged in user'

      it 'gives unauthorized' do
        get :edit, params: { id: work.id }

        expect(response.status).to eq 401
      end
    end
  end

  describe '#new' do
    it 'redirect to user login' do
      get :new
      expect(response).to redirect_to paths.new_user_session_path(locale: :en)
    end

    xcontext 'with a logged in user' do
      include_context 'with a logged in user'

      it 'is successful' do
        get :new

        expect(response).to be_successful
      end

      it 'renders a form' do
        get :new

        expect(assigns[:form]).to be_kind_of Hyrax::WorkForm
      end
    end
  end

  describe '#show' do
    shared_examples 'allows show access' do
      it 'allows access' do
        get :show, params: { id: work.id }

        expect(response.status).to eq 200
      end

      it 'resolves ntriples' do
        get :show, params: { id: work.id }, format: :nt

        expect(RDF::Reader.for(:ntriples).new(response.body).objects)
          .to include(RDF::Literal(title.first))
      end

      it 'resolves turtle' do
        get :show, params: { id: work.id }, format: :ttl

        expect(RDF::Reader.for(:ttl).new(response.body).objects)
          .to include(RDF::Literal(title.first))
      end

      it 'resolves jsonld' do
        get :show, params: { id: work.id }, format: :jsonld

        expect(RDF::Reader.for(:jsonld).new(response.body).objects)
          .to include(RDF::Literal(title.first))
      end

      xit 'resolves json' do
        get :show, params: { id: work.id }, format: :json

        expect(response.body).to include(title.first)
      end
    end

    it 'gives a 404 for a missing object' do
      expect { get :show, params: { id: 'missing_id' } }
        .to raise_error Blacklight::Exceptions::RecordNotFound
    end

    it 'redirects to new user login' do
      get :show, params: { id: work.id }

      expect(response).to redirect_to paths.new_user_session_path(locale: :en)
    end

    context 'when indexed as public' do
      let(:index_document) do
        Wings::ActiveFedoraConverter.convert(resource: work).to_solr.tap do |doc|
          doc[Hydra.config.permissions.read.group] = 'public'
        end
      end

      before { ActiveFedora::SolrService.add(index_document, softCommit: true) }

      it_behaves_like 'allows show access'
    end

    context 'when the user has read access' do
      include_context 'with a logged in user'

      let(:index_document) do
        Wings::ActiveFedoraConverter.convert(resource: work).to_solr.tap do |doc|
          doc[Hydra.config.permissions.read.individual] = [user.user_key]
        end
      end

      before { ActiveFedora::SolrService.add(index_document, softCommit: true) }

      it_behaves_like 'allows show access'
    end
  end
end
