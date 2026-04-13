# frozen_string_literal: true

module Rails
  module Schema
    module Extractor
      # Wraps a raw schema entry for a table that has no corresponding ActiveRecord
      # model, giving it the model-like interface expected by GraphBuilder and
      # ColumnReader (#name, #table_name).
      class TableProxy
        attr_reader :name, :table_name

        def initialize(table_name)
          @table_name = table_name
          @name = "#{table_name} (table)"
        end
      end
    end
  end
end
