RSpec.describe Hyrax::CollectionType, type: :model do
  let(:collection_type) { create(:user_collection_type) }

  it "has basic metadata" do
    expect(collection_type).to respond_to(:title)
    expect(collection_type.title).not_to be_empty
    expect(collection_type).to respond_to(:description)
    expect(collection_type.description).not_to be_empty
    expect(collection_type).to respond_to(:machine_id)
    expect(collection_type.machine_id).not_to be_empty
  end

  it "has configuration properties with defaults" do
    expect(collection_type.nestable).to be_truthy
    expect(collection_type.discovery).to be_truthy
    expect(collection_type.sharing).to be_truthy
    expect(collection_type.multiple_membership).to be_truthy
    expect(collection_type.require_membership).to be_falsey
    expect(collection_type.workflow).to be_falsey
    expect(collection_type.visibility).to be_falsey
  end
end
