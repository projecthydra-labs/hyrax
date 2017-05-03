# frozen_string_literal: true

require 'spec_helper'
RSpec.describe Hyrax::Forms::AdminSetForm do
  let(:form) { described_class.new(model) }

  describe "[] accessors" do
    let(:model) { AdminSet.new(description: ['one']) }
    it "cast to scalars" do
      expect(form[:description]).to eq 'one'
    end
  end

  describe "#permission_template" do
    subject { form.permission_template }
    context "when the PermissionTemplate doesn't exist" do
      let(:model) { create(:admin_set) }
      it "gets created" do
        expect(subject).to be_instance_of Hyrax::Forms::PermissionTemplateForm
        expect(subject.model).to be_instance_of Hyrax::PermissionTemplate
      end
    end

    context "when the PermissionTemplate exists" do
      let(:permission_template) { Hyrax::PermissionTemplate.find_by(admin_set_id: model.id) }
      let(:model) { create(:admin_set, with_permission_template: true) }
      it "uses the existing template" do
        expect(subject).to be_instance_of Hyrax::Forms::PermissionTemplateForm
        expect(subject.model).to eq permission_template
      end
    end
  end

  describe "model_attributes" do
    let(:raw_attrs) { ActionController::Parameters.new(title: 'test title') }
    subject { described_class.model_attributes(raw_attrs) }

    it "casts to enums" do
      expect(subject[:title]).to eq ['test title']
    end
  end
end
