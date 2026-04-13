# frozen_string_literal: true

module Rails
  module Schema
    module Transformer
      class Node
        attr_reader :id, :table_name, :columns, :group, :node_type

        def initialize(id:, table_name:, columns: [], group: [], node_type: "model")
          @id = id
          @table_name = table_name
          @columns = columns
          @group = group
          @node_type = node_type
        end

        def to_h
          h = { id: @id, table_name: @table_name, columns: @columns, node_type: @node_type }
          h[:group] = @group unless @group.empty?
          h
        end
      end
    end
  end
end
