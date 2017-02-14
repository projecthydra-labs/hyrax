require 'spec_helper'

describe Hyrax::Actors::ApplyOrderActor do
  describe '#update' do
    let(:user) { create(:admin) }
    let(:ability) { Ability.new(user) }
    let(:curation_concern) { create(:work_with_one_child, user: user) }
    let(:child) { GenericWork.new(id: "blahblah3") }

    subject do
      Hyrax::Actors::ActorStack.new(curation_concern,
                                    ability,
                                    [described_class,
                                     Hyrax::Actors::GenericWorkActor])
    end
    let(:root_actor) { double }
    before do
      allow(Hyrax::Actors::RootActor).to receive(:new).and_return(root_actor)
      allow(root_actor).to receive(:update).with({}).and_return(true)
    end

    context 'with ordered_member_ids that are already associated with the parent' do
      let(:curation_concern) { create(:work_with_two_children, user: user) }
      let(:attributes) { { ordered_member_ids: ["BlahBlah1"] } }
      before do
        curation_concern.apply_depositor_metadata(user.user_key)
        curation_concern.save!
      end
      it "attaches the parent" do
        expect(subject.update(attributes)).to be true
      end
    end

    context 'with ordered_members_ids that arent associated with the curation concern yet.' do
      let(:attributes) { { ordered_member_ids: [child.id] } }
      before do
        # TODO: This can be moved into the Factory
        child.title = ["Generic Title"]
        child.apply_depositor_metadata(user.user_key)
        child.save!
        curation_concern.apply_depositor_metadata(user.user_key)
        curation_concern.save!
      end

      it "attaches the parent" do
        expect(subject.update(attributes)).to be true
      end
    end

    context 'without an ordered_member_id that was associated with the curation concern' do
      let(:curation_concern) { create(:work_with_two_children, user: user) }
      let(:attributes) { { ordered_member_ids: ["BlahBlah2"] } }
      before do
        child.title = ["Generic Title"]
        child.apply_depositor_metadata(user.user_key)
        child.save!
        curation_concern.apply_depositor_metadata(user.user_key)
        curation_concern.save!
      end
      it "removes the first child" do
        expect(subject.update(attributes)).to be true
        expect(curation_concern.members.size).to eq(1)
        expect(curation_concern.ordered_member_ids.size).to eq(1)
      end
    end
  end
end
