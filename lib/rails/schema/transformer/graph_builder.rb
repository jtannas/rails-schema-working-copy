# frozen_string_literal: true

require "set"

module Rails
  module Schema
    module Transformer
      class GraphBuilder
        def initialize(column_reader: Extractor::ColumnReader.new, association_reader: Extractor::AssociationReader.new,
                       configuration: ::Rails::Schema.configuration)
          @column_reader = column_reader
          @association_reader = association_reader
          @group_proc = configuration.resolved_group_proc
        end

        def build(models, tableless_models: [], table_proxies: [])
          all_objects = models + tableless_models + table_proxies
          all_ids = assign_unique_ids(all_objects)
          name_to_id = build_name_to_id(all_ids)
          edge_end = models.size + tableless_models.size
          nodes = build_nodes(all_ids, models.size, edge_end)
          edges = build_all_edges(all_ids, edge_end, name_to_id)
          { nodes: nodes.map(&:to_h), edges: edges.map(&:to_h),
            metadata: build_metadata(models, tableless_models, table_proxies) }
        end

        private

        def build_name_to_id(model_ids)
          model_ids.each_with_object({}) { |(m, uid), map| map[m.name] ||= uid }
        end

        def assign_unique_ids(models)
          counts = models.group_by(&:name).transform_values(&:size)
          models.map do |m|
            uid = counts[m.name] > 1 ? "#{m.name} (#{m.table_name})" : m.name
            [m, uid]
          end
        end

        def build_all_edges(all_ids, edge_end, name_to_id)
          deduplicate_edges(all_ids.first(edge_end).flat_map { |obj, uid| build_edges(obj, uid, name_to_id) })
        end

        def build_nodes(all_ids, model_end, tableless_end)
          all_ids.each_with_index.map do |(obj, uid), idx|
            build_node(obj, uid, node_type: node_type_for(idx, model_end, tableless_end))
          end
        end

        def node_type_for(idx, model_end, tableless_end)
          return "model" if idx < model_end

          idx < tableless_end ? "tableless_model" : "table_only"
        end

        def build_node(model, unique_id, node_type: "model")
          group = node_type == "model" && @group_proc ? Array(@group_proc.call(model)) : []
          columns = node_type == "tableless_model" ? [] : @column_reader.read(model)
          Node.new(id: unique_id, table_name: model.table_name, columns: columns, group: group, node_type: node_type)
        end

        def build_edges(model, unique_id, name_to_id)
          @association_reader.read(model).filter_map do |assoc|
            next unless name_to_id.key?(assoc[:to])

            Edge.new(from: unique_id, to: name_to_id[assoc[:to]], association_type: assoc[:association_type],
                     label: assoc[:label], foreign_key: assoc[:foreign_key],
                     through: assoc[:through], polymorphic: assoc[:polymorphic])
          end
        end

        def deduplicate_edges(edges)
          edges = deduplicate_habtm(edges)
          deduplicate_has_many_belongs_to(edges)
        end

        def deduplicate_habtm(edges)
          habtm_first = {}

          edges.each_with_object([]) do |edge, result|
            next result << edge unless edge.association_type == "has_and_belongs_to_many"

            pair = [edge.from, edge.to].sort
            if habtm_first.key?(pair)
              habtm_first[pair].reverse_label = edge.label
            else
              habtm_first[pair] = edge
              result << edge
            end
          end
        end

        def deduplicate_has_many_belongs_to(edges)
          hm_lookup = build_has_many_lookup(edges)

          edges.each_with_object([]) do |edge, result|
            if edge.association_type == "belongs_to"
              hm_edge = hm_lookup[[edge.from, edge.to, edge.foreign_key]]
              if hm_edge
                hm_edge.reverse_label = edge.label
                hm_edge.reverse_association_type = edge.association_type
                next
              end
            end
            result << edge
          end
        end

        def build_has_many_lookup(edges)
          edges.each_with_object({}) do |edge, lookup|
            next unless %w[has_many has_one].include?(edge.association_type)

            lookup[[edge.to, edge.from, edge.foreign_key]] = edge
          end
        end

        def build_metadata(models, tableless_models = [], table_proxies = [])
          {
            generated_at: Time.now.utc.iso8601,
            model_count: models.size,
            tableless_model_count: tableless_models.size,
            table_only_count: table_proxies.size,
            rails_version: defined?(::Rails.version) ? ::Rails.version : nil
          }
        end
      end
    end
  end
end
