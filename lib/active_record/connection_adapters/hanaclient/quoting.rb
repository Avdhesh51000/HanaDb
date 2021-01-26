module ActiveRecord
  module ConnectionAdapters
    module Hanaclient
      module Quoting

        # Replaces any " symbols with ""
        def quote_column_name(name)
          @quoted_column_names = @quoted_column_names || {}
          @quoted_column_names[name] ||= %Q("#{super.gsub('"', '""')}").freeze 
        end

        def quoted_true
          "true".freeze
        end

        def unquoted_true
          "true".freeze
        end

        def quoted_false
          "false".freeze
        end

        def unquoted_false
          "false".freeze
        end

        def quote_table_name_for_assignment(table, attr)
          quote_column_name(attr)
        end

        def quote_table_name name
          name.to_s
        end

        # Gets the time from a date string
        def quoted_time(value)
          quoted_date(value).match(/[0-2][0-9]:[0-9][0-9]:[0-9][0-9]/)[0]
        end

        def fetch_type_metadata(sql_type)
          Hanaclient::TypeMetadata.new(super(sql_type))
        end

      end
    end
  end
end
