# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrax::SelectTypePresenter do
  let(:instance) { described_class.new(model) }
  let(:model) { GenericWork }

  describe "#icon_class" do
    subject { instance.icon_class }
    it { is_expected.to eq 'fa fa-file-text-o' }
  end

  describe "#description" do
    subject { instance.description }
    it { is_expected.to eq 'Generic work works' }
  end

  describe "#name" do
    subject { instance.name }
    it { is_expected.to eq 'Generic Work' }
  end
end
