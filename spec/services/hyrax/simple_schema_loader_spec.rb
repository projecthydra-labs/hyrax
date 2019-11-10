# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrax::SimpleSchemaLoader do
  subject(:schema_loader) { described_class.new }

  describe '#attributes_for' do
    it 'provides an attributes hash' do
      expect(schema_loader.attributes_for(schema: :core_metadata))
        .to include(title:     Valkyrie::Types::Array.of(Valkyrie::Types::String),
                    depositor: Valkyrie::Types::String)
    end

    it 'raises an error for an undefined schema' do
      expect { schema_loader.attributes_for(schema: :NOT_A_SCHEMA) }
        .to raise_error described_class::UndefinedSchemaError
    end
  end
end
