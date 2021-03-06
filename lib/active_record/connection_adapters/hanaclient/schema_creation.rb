module ActiveRecord
  module ConnectionAdapters
    module Hanaclient
      class SchemaCreation < AbstractAdapter::SchemaCreation
        private

          def visit_AddColumnDefinition(o)
            "ADD (#{accept(o.column)})"
          end

          def visit_ChangeColumnDefinition(o)
            change_column_sql = "ALTER (#{accept(o.column)})"
          end

          def visit_TableDefinition(o)

            if o.temporary && o.row_table
              table_type = 'GLOBAL TEMPORARY ROW'
            elsif o.temporary
              table_type = 'GLOBAL TEMPORARY COLUMN'
            elsif o.row_table
              table_type = 'ROW'
            else
              table_type = 'COLUMN'
            end

            create_sql = "CREATE #{table_type} TABLE #{quote_table_name(o.name)} "

            statements = o.columns.map { |c| accept c }
            statements << accept(o.primary_keys) if o.primary_keys

            if supports_indexes_in_create?
              statements.concat(o.indexes.map { |column_name, options| index_in_create(o.name, column_name, options) })
            end

            if supports_foreign_keys_in_create?
              statements.concat(o.foreign_keys.map { |to_table, options| foreign_key_in_create(o.name, to_table, options) })
            end

            create_sql << "(#{statements.join(', ')})" if statements.present?
            add_table_options!(create_sql, table_options(o))
            create_sql << " AS #{@conn.to_sql(o.as)}" if o.as
            create_sql
          end

          def visit_PrimaryKeyDefinition(o)
            "PRIMARY KEY (#{o.name.map{|name| quote_column_name(name)}.join(', ')})"
          end

          def add_column_options!(sql, options)
            sql << " DEFAULT #{quote_default_expression(options[:default], options[:column])}" if options_include_default?(options)
            # must explicitly check for :null to allow change_column to work on migrations
            if options[:null] == false
              sql << " NOT NULL"
            end
            if options[:primary_key] == true
              sql << " PRIMARY KEY"
            end
            if options[:auto_increment] == true
              sql << " GENERATED BY DEFAULT AS IDENTITY"
            end
            sql
          end

      end
    end
  end
end
