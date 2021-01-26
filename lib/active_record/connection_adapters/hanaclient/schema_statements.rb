module ActiveRecord
  module ConnectionAdapters
    module Hanaclient
      module SchemaStatements

        def create_table(table_name, comment: nil, **options)
          td = create_table_definition table_name, options[:temporary], options[:row_table], options[:options], options[:as], comment: comment

          if options[:id] != false && !options[:as]
            pk = options.fetch(:primary_key) do
              Base.get_primary_key table_name.to_s.singularize
            end

            if pk.is_a?(Array)
              td.primary_keys pk
            else
              td.primary_key pk, options.fetch(:id, :primary_key), options
            end
          end

          yield td if block_given?

          if options[:force]
            drop_table(table_name, **options, if_exists: true)
          end

          result = execute schema_creation.accept td

          unless supports_indexes_in_create?
            td.indexes.each do |column_name, index_options|
              add_index(table_name, column_name, index_options)
            end
          end

          if supports_comments? && !supports_comments_in_create?
            change_table_comment(table_name, comment) if comment.present?

            td.columns.each do |column|
              change_column_comment(table_name, column.name, column.comment) if column.comment.present?
            end
          end

          result
        end

        # Returns an array of IndexDefinition objects for the given table.
        def indexes(table_name, name = nil)
          if name
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
              Passing name to #indexes is deprecated without replacement.
            MSG
          end

          scope = quoted_scope(table_name)

          sql = "SELECT TABLE_NAME, INDEX_NAME, CONSTRAINT, COLUMN_NAME FROM SYS.INDEX_COLUMNS WHERE TABLE_NAME = #{scope[:schema]} AND SCHEMA_NAME = #{scope[:name]}"
          exec_and_clear(sql, "SCHEMA") do |stmt|
            index_hashes = {}
            while HA.instance.api.hanaclient_fetch_next(stmt) == 1
              table_name =  HA.instance.api.hanaclient_get_column(stmt, 0)[1]
              index_name =  HA.instance.api.hanaclient_get_column(stmt, 1)[1]
              constraint =  HA.instance.api.hanaclient_get_column(stmt, 2)[1]
              column_name = HA.instance.api.hanaclient_get_column(stmt, 3)[1]
              next if constraint.to_s.scan(/PRIMARY KEY/)

              index_hashes[index_name] ||= IndexDefinition.new(table_name, index_name, constraint.to_s.scan(/UNIQUE/) ? true : false, [], {}, nil, nil, nil, nil, nil)
              index_hashes[index_name].columns << column_name
            end

            index_hashes.values
          end
        end

        def rename_table(table_name, new_name)
          execute "RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}"
          rename_table_indexes(table_name, new_name)
        end

        def drop_table(table_name, options = {})
          begin
            execute "DROP TABLE #{quote_table_name(table_name)} CASCADE"
          rescue ActiveRecord::StatementInvalid => e
            raise e unless options[:if_exists]
          end
        end

        def change_column(table_name, column_name, type, options = {})
          column = column_for(table_name, column_name)

          unless options.key?(:default)
            options[:default] = column.default
          end

          unless options.key?(:null)
            options[:null] = column.null
          end

          unless options.key?(:comment)
            options[:comment] = column.comment
          end

          td = create_table_definition(table_name)
          cd = td.new_column_definition(column.name, type, options)
          change_column_sql = schema_creation.accept(ChangeColumnDefinition.new(cd, column.name))

          execute("ALTER TABLE #{quote_table_name(table_name)} #{change_column_sql}")
        end

        def change_column_default(table_name, column_name, default_or_changes)
          default = extract_new_default_value(default_or_changes)
          column = column_for(table_name, column_name)
          change_column(table_name, column_name, column.sql_type, default: default)
        end

        def change_column_null(table_name, column_name, null, default = nil)
          column = column_for(table_name, column_name)

          unless null || default.nil?
            execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
          end

          change_column(table_name, column_name, column.sql_type, null: null)
        end

        def rename_column(table_name, column_name, new_column_name)
          execute("RENAME COLUMN #{quote_table_name(table_name)}.#{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}")
        end

        def remove_index(table_name, options = {})
          index_name = index_name_for_remove(table_name, options)
          execute("DROP INDEX #{quote_column_name(index_name)}")
        end

        def rename_index(table_name, old_name, new_name)
          validate_index_length!(table_name, new_name)
          execute("RENAME INDEX #{quote_column_name(old_name)} TO #{quote_column_name(new_name)}")
        end

        # Returns an array of ForeignKeyDefinitions for a given table
        def foreign_keys(table_name)
          raise ArgumentError unless table_name.present?

          scope = quoted_scope(table_name)

          fk_info = exec_query(<<-SQL.strip_heredoc, "SCHEMA")
            SELECT REFERENCED_TABLE_NAME AS "to_table",
                   REFERENCED_COLUMN_NAME AS "primary_key",
                   COLUMN_NAME AS "column",
                   CONSTRAINT_NAME AS "name",
                   UPDATE_RULE AS "on_update",
                   DELETE_RULE AS "on_delete"
            FROM SYS.REFERENTIAL_CONSTRAINTS
            WHERE SCHEMA_NAME = #{scope[:schema]}
              AND TABLE_NAME = #{scope[:name]}
          SQL

          fk_info.map do |row|
            options = {
              column: row["column"],
              name: row["name"],
              primary_key: row["primary_key"]
            }

            options[:on_update] = extract_foreign_key_action(row["on_update"])
            options[:on_delete] = extract_foreign_key_action(row["on_delete"])

            ForeignKeyDefinition.new(table_name, row["to_table"], options)
          end
        end

        def extract_foreign_key_action(specifier)
          case specifier
          when "CASCADE"; :cascade
          when "SET NULL"; :nullify
          end
        end

        def change_table_comment(table_name, comment)
          execute "COMMENT ON TABLE #{quote_table_name(table_name)} IS #{quote(comment)}"
        end

        def change_column_comment(table_name, column_name, comment)
          execute "COMMENT ON COLUMN #{quote_table_name(table_name)}.#{quote_column_name(column_name)} IS #{quote(comment)}"
        end

        # Returns the sql for a given type
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, **) # :nodoc:
          type = type.to_sym if type
          if native = native_database_types[type]
            column_type_sql = (native.is_a?(Hash) ? native[:name] : native).dup

            if type == :integer
              case limit
              when 1
                column_type_sql = "TINYINT"
              when 2
                column_type_sql = "SMALLINT"
              when nil, 3, 4
                column_type_sql = "INTEGER"
              when 5..8
                column_type_sql = "BIGINT"
              else
                raise(ActiveRecordError, "No integer type has byte size #{limit}.")
              end
            elsif type == :float
              case limit
              when nil, 1..24
                column_type_sql = "REAL"
              when 25..53
                column_type_sql = "DOUBLE"
              else
                raise(ActiveRecordError, "No float type has byte size #{limit}.")
              end
            elsif type == :decimal # ignore limit, use precision and scale
              scale ||= native[:scale]

              if precision ||= native[:precision]
                if scale
                  column_type_sql << "(#{precision},#{scale})"
                else
                  column_type_sql << "(#{precision})"
                end
              elsif scale
                raise ArgumentError, "Error adding decimal column: precision cannot be empty if scale is specified"
              end
            elsif type == :binary
              if limit.nil? || limit.between?(1,5000)
                column_type_sql = "VARBINARY(#{limit ? limit : 5000})"
              else
                column_type_sql = "BLOB"
              end
            elsif type == :unicode
              if limit.nil? || limit.between?(1,5000)
                column_type_sql = "NVARCHAR(#{limit ? limit : 5000})"
              else
                column_type_sql = "NCLOB"
              end
            elsif (type != :primary_key) && (limit ||= native.is_a?(Hash) && native[:limit])
              column_type_sql << "(#{limit})"
            end

            column_type_sql.upcase
          else
            type.to_s.upcase
          end
        end

        private

          def data_source_sql(name = nil, type: nil)
            scope = quoted_scope(name, type: type)

            table_sql = "SELECT TABLE_NAME FROM SYS.TABLES WHERE SCHEMA_NAME = #{scope[:schema]}"
            table_sql << " AND TABLE_NAME = #{scope[:name]}" if scope[:name]

            view_sql = "SELECT VIEW_NAME AS TABLE_NAME FROM SYS.VIEWS WHERE SCHEMA_NAME = #{scope[:schema]}"
            view_sql << " AND VIEW_NAME = #{scope[:name]}" if scope[:name]

            case type
            when "BASE TABLE"
              return table_sql
            when "VIEW"
              return view_sql
            end

            "#{table_sql} UNION ALL #{view_sql}"
          end

          def quoted_scope(name = nil, type: nil)
            schema, name = extract_schema_qualified_name(name)
            scope = {}
            scope[:schema] = schema ? quote(schema) : "CURRENT_SCHEMA"
            scope[:name] = quote(name) if name
            scope
          end

          # Extracts the schema and table name from a string of the form "schema.table"
          def extract_schema_qualified_name(string)
            schema, name = string.to_s.scan(/[^`.\s]+|`[^`]*`/)
            schema, name = nil, schema unless name
            [schema, name]
          end

      end
    end
  end
end
