# frozen_string_literal: true

RSpec.describe Rails::Schema::Extractor::TableProxy do
  subject(:proxy) { described_class.new("users") }

  describe "#table_name" do
    it "returns the raw table name" do
      expect(proxy.table_name).to eq("users")
    end
  end

  describe "#name" do
    it "returns the table name suffixed with (table)" do
      expect(proxy.name).to eq("users (table)")
    end

    it "uses the raw table name as the prefix" do
      proxy = described_class.new("schema_migrations")

      expect(proxy.name).to eq("schema_migrations (table)")
    end
  end

  describe "uniqueness of name vs table_name" do
    it "name and table_name are never equal" do
      expect(proxy.name).not_to eq(proxy.table_name)
    end
  end
end
