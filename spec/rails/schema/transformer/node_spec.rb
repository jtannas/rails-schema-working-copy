# frozen_string_literal: true

RSpec.describe Rails::Schema::Transformer::Node do
  describe "#to_h" do
    it "includes group when non-empty" do
      node = described_class.new(id: "User", table_name: "users", group: ["Admin"])

      expect(node.to_h[:group]).to eq(["Admin"])
    end

    it "omits group when empty" do
      node = described_class.new(id: "User", table_name: "users")

      expect(node.to_h).not_to have_key(:group)
    end

    it "defaults node_type to 'model'" do
      node = described_class.new(id: "User", table_name: "users")

      expect(node.to_h[:node_type]).to eq("model")
    end

    it "includes node_type in to_h" do
      node = described_class.new(id: "users (table)", table_name: "users", node_type: "table_only")

      expect(node.to_h[:node_type]).to eq("table_only")
    end

    it "reflects tableless_model node_type" do
      node = described_class.new(id: "Ghost", table_name: "ghosts", node_type: "tableless_model")

      expect(node.to_h[:node_type]).to eq("tableless_model")
    end
  end
end
