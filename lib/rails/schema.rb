# frozen_string_literal: true

require_relative "schema/version"
require_relative "schema/configuration"
require_relative "schema/transformer/node"
require_relative "schema/transformer/edge"
require_relative "schema/extractor/schema_file_parser"
require_relative "schema/extractor/structure_sql_parser"
require_relative "schema/extractor/packwerk_discovery"
require_relative "schema/extractor/model_scanner"
require_relative "schema/extractor/table_proxy"
require_relative "schema/extractor/column_reader"
require_relative "schema/extractor/association_reader"
require_relative "schema/transformer/graph_builder"
require_relative "schema/renderer/html_generator"

module Rails
  module Schema
    class Error < StandardError; end

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def reset_configuration!
        @configuration = Configuration.new
      end

      def generate(output: nil)
        if mongoid_mode?
          generate_mongoid(output: output)
        else
          generate_active_record(output: output)
        end
      end

      def mongoid_mode?
        case configuration.schema_format
        when :mongoid
          true
        when :auto
          defined?(::Mongoid::Document) ? true : false
        else
          false
        end
      end

      private

      def generate_active_record(output:)
        schema_data = parse_schema
        scanner = Extractor::ModelScanner.new(schema_data: schema_data)
        models = scanner.scan
        tableless_models = scanner.scan_tableless
        table_proxies = build_table_proxies(schema_data, models + tableless_models)
        column_reader = Extractor::ColumnReader.new(schema_data: schema_data)
        builder = Transformer::GraphBuilder.new(column_reader: column_reader)
        graph_data = builder.build(models, tableless_models: tableless_models, table_proxies: table_proxies)
        graph_data[:metadata][:mode] = "active_record"
        Renderer::HtmlGenerator.new(graph_data: graph_data).render_to_file(output)
      end

      def build_table_proxies(schema_data, claimed_models)
        return [] if schema_data.nil? || schema_data.empty?

        claimed_tables = claimed_models.to_set(&:table_name)
        schema_data.keys
                   .reject { |t| claimed_tables.include?(t) || excluded_table?(t) }
                   .map { |t| Extractor::TableProxy.new(t) }
                   .sort_by(&:table_name)
      end

      def excluded_table?(table_name)
        return true if configuration.exclude_table_if&.call(table_name)

        configuration.exclude_tables.any? do |pattern|
          if pattern.end_with?("*")
            table_name.start_with?(pattern.delete_suffix("*"))
          else
            table_name == pattern
          end
        end
      end

      def require_mongoid_extractors
        require_relative "schema/extractor/mongoid/model_scanner"
        require_relative "schema/extractor/mongoid/model_adapter"
        require_relative "schema/extractor/mongoid/column_reader"
        require_relative "schema/extractor/mongoid/association_reader"
      end

      def generate_mongoid(output:)
        require_mongoid_extractors

        raw_models = Extractor::Mongoid::ModelScanner.new.scan
        models = raw_models.map { |m| Extractor::Mongoid::ModelAdapter.new(m) }
        column_reader = Extractor::Mongoid::ColumnReader.new
        association_reader = Extractor::Mongoid::AssociationReader.new
        graph_data = Transformer::GraphBuilder.new(
          column_reader: column_reader,
          association_reader: association_reader
        ).build(models)
        graph_data[:metadata][:mode] = "mongoid"
        generator = Renderer::HtmlGenerator.new(graph_data: graph_data)
        generator.render_to_file(output)
      end

      def parse_schema
        case configuration.schema_format
        when :ruby
          Extractor::SchemaFileParser.new.parse
        when :sql
          Extractor::StructureSqlParser.new.parse
        when :auto
          data = Extractor::SchemaFileParser.new.parse
          data.empty? ? Extractor::StructureSqlParser.new.parse : data
        end
      end
    end
  end
end

require_relative "schema/railtie" if defined?(Rails::Railtie)
