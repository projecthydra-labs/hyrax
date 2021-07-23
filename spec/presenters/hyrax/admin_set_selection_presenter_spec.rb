# frozen_string_literal: true

RSpec.describe Hyrax::AdminSetSelectionPresenter do
  subject(:presenter) { described_class.new(admin_sets: admin_sets) }

  let(:admin_sets) do
    [FactoryBot.valkyrie_create(:hyrax_admin_set, title: 'first'),
     FactoryBot.valkyrie_create(:hyrax_admin_set, title: 'second'),
     FactoryBot.valkyrie_create(:hyrax_admin_set, title: 'third')]
  end

  describe '#select_options' do
    it 'builds out the options for a select dropdown' do
      expect(presenter.select_options)
        .to contain_exactly ["first", admin_sets[0].id, an_instance_of(Hash)],
                            ["second", admin_sets[1].id, an_instance_of(Hash)],
                            ["third", admin_sets[2].id, an_instance_of(Hash)]
    end
  end

  describe described_class::OptionsEntry do
    subject(:entry) { described_class.new(admin_set: admin_set) }

    let(:admin_set) do
      FactoryBot.valkyrie_create(:hyrax_admin_set, title: 'first')
    end

    its(:id) { is_expected.to eq admin_set.id }

    describe '#data' do
      it 'is a hash with no release delay and restricted visibility' do
        expect(entry.data)
          .to include 'data-release-no-delay' => true
      end

      context 'with a permission template' do
        subject(:entry) do
          described_class
            .new(admin_set: admin_set, permission_template: permission_template)
        end

        let(:permission_template) do
          FactoryBot.create(:permission_template,
                            :with_immediate_release,
                            source_id: admin_set.id.to_s)
        end

        it 'indicates no release delay' do
          expect(entry.data).to include 'data-release-no-delay' => true
        end

        context 'and delayed release' do
          let(:permission_template) do
            FactoryBot.create(:permission_template,
                              :with_delayed_release,
                              source_id: admin_set.id.to_s)
          end

          it 'indicates a release delay' do
            expect(entry.data)
              .to include 'data-release-before-date' => true,
                          'data-release-date' => permission_template.release_date
          end
        end
      end
    end

    describe '#label' do
      it 'is the title' do
        expect(entry.label).to eq 'first'
      end
    end
  end
end
