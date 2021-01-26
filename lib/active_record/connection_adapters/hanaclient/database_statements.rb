module ActiveRecord
  module ConnectionAdapters
    module Hanaclient
      module DatabaseStatements
        # Executes the SQL statement in the context of this connection and returns
        # the raw result from the connection adapter.
        def execute(sql, name = nil)
          log(sql, name) do
            if HA.instance.api.hanaclient_execute_immediate(@connection, sql) == 0
              result, errstr = HA.instance.api.hanaclient_error(@connection)
              raise ActiveRecord::StatementInvalid.new(errstr)
            end
          end
        end

        # Executes +sql+ statement in the context of this connection using
        # +binds+ as the bind substitutes. +name+ is logged along with
        # the executed +sql+ statement.
        def exec_query(sql, name = "SQL", binds = [], prepare: false)
          exec_and_clear(sql, name, binds, prepare: prepare) do |stmt|
            record = []
            columns = []

            max_cols = HA.instance.api.hanaclient_num_cols(stmt)
            if( max_cols > 0 )
              columns = max_cols.times.collect{ |x| HA.instance.api.hanaclient_get_column_info(stmt, x)[2] }

              while HA.instance.api.hanaclient_fetch_next(stmt) == 1
                result = []

                max_cols.times do |cols|
                  result << HA.instance.api.hanaclient_get_column(stmt, cols)[1]
                end

                record << result
              end
            end

            ActiveRecord::Result.new(columns, record)
          end
        end

        # Executes the truncate statement.
        def truncate(table_name, name = nil)
          exec_query("TRUNCATE TABLE #{quote_table_name(table_name)}", name)
        end

        def exec_insert(sql, name = nil, binds = [], pk = nil, sequence_name = nil)
          result = exec_query(sql, name, binds)
          unless sequence_name
            table_ref = extract_table_ref_from_insert_sql(sql)
            if table_ref
              pk = primary_key(table_ref) if pk.nil?
              pk = suppress_composite_primary_key(pk)
              sequence_name = default_sequence_name(table_ref, pk)
            end
            return result unless sequence_name
          end
          last_insert_id_result(sequence_name)
        end

        # Executes delete +sql+ statement in the context of this connection using
        # +binds+ as the bind substitutes. +name+ is logged along with
        # the executed +sql+ statement.
        def exec_delete(sql, name = nil, binds = [])
          exec_and_clear(sql, name, binds) do |stmt|
            HA.instance.api.hanaclient_affected_rows(stmt)
          end
        end
        alias :exec_update :exec_delete

        def reset_transaction #:nodoc:
          @transaction_manager = ConnectionAdapters::Hanaclient::TransactionManager.new(self)
        end

        def commit_db_transaction()
          HA.instance.api.hanaclient_commit(@connection)
        end

        def exec_rollback_db_transaction()
          HA.instance.api.hanaclient_rollback(@connection)
        end

        def default_sequence_name(table, column)
          query_value(<<-end_sql, "SCHEMA")
            SELECT SEQUENCE_NAME FROM SEQUENCES WHERE SEQUENCE_NAME like ('%' || (SELECT column_id from table_columns where table_name = #{quote(table.gsub('"', ''))} AND column_name = #{quote(column.gsub('"', ''))}) || '%')
          end_sql
        end

        def insert_fixtures(fixtures, table_name)
          fixtures.each do |fixture|
            insert_fixture(fixture, table_name)
          end
        end

        def insert_fixtures_set(fixture_set, tables_to_delete = [])
          disable_referential_integrity do
            transaction(requires_new: true) do
              tables_to_delete.each { |table| delete "DELETE FROM #{quote_table_name(table)}", "Fixture Delete" }

              fixture_set.each do |table_name, rows|
                rows.each { |row| insert_fixture(row, table_name) }
              end
            end
          end
        end

        # This is not supported. Can't insert an empty column
        def empty_insert_statement_value
          raise NotImplementedError
        end

        private
          def suppress_composite_primary_key(pk)
            pk unless pk.is_a?(Array)
          end

      end
    end
  end
end
