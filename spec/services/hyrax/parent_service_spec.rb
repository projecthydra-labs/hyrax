# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Hyrax::ParentService do
  subject { described_class }

  describe ".parent_for" do
    context "when there's no ID" do
      it "is nil" do
        expect(subject.parent_for(nil)).to eq nil
      end
    end
  end
end
