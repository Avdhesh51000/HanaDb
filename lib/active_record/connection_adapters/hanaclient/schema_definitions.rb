module ActiveRecord
  module ConnectionAdapters
    module Hanaclient
      class ReferenceDefinition < ActiveRecord::ConnectionAdapters::ReferenceDefinition
      end

      module ColumnMethods
        def primary_key(name, type = :primary_key, **options)
          options[:auto_increment] = true if [:integer, :bigint].include?(type) && !options.key?(:default)
          super
        end

        # Generates a function for each supported database type
        [
          :string,
          :integer,
          :float,
          :decimal,
          :time,
          :date,
          :seconddate,
          :timestamp,
          :binary,
          :unicode,
          :text,
          :boolean
        ].each do |column_type|
          module_eval <<-CODE, __FILE__, __LINE__ + 1
            def #{column_type}(*args, **options)
              args.each { |name| column(name, :#{column_type}, options) }
            end
          CODE
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        attr_accessor :indexes
        attr_reader :name, :row_table, :temporary, :options, :as, :foreign_keys, :comment

        def initialize(name, temporary = false, row_table = false, options = nil, as = nil, comment: nil)
          @columns_hash = {}
          @indexes = []
          @foreign_keys = []
          @primary_keys = nil
          @row_table = row_table
          @temporary = temporary
          @options = options
          @as = as
          @name = name
          @comment = comment
        end


        def new_column_definition(name, type, **options)
          if type == :primary_key
            type = :integer
            options[:limit] ||= 8
            options[:auto_increment] = true
            options[:primary_key] = true
          end
          super
        end
      end

      class AlterTable < ActiveRecord::ConnectionAdapters::AlterTable
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end
