module ActiveRecord
  module ConnectionAdapters
    module Hanaclient
      class Name # :nodoc:
        SEPARATOR = "."
        attr_reader :schema, :identifier

        def initialize(schema, identifier)
          @schema, @identifier = Utils.unquote_identifier(schema), Utils.unquote_identifier(identifier)
        end

        def to_s
          parts.join SEPARATOR
        end

        def quoted
          if schema
            PG::Connection.quote_ident(schema) << SEPARATOR << PG::Connection.quote_ident(identifier)
          else
            PG::Connection.quote_ident(identifier)
          end
        end

        def ==(o)
          o.class == self.class && o.parts == parts
        end
        alias_method :eql?, :==

        def hash
          parts.hash
        end

        protected
          def parts
            @parts ||= [@schema, @identifier].compact
          end
      end

      module Utils # :nodoc:
        extend self

        # Returns an instance of <tt>ActiveRecord::ConnectionAdapters::Hanaclient::Name</tt>
        # extracted from +string+.
        # +schema+ is +nil+ if not specified in +string+.
        # +schema+ and +identifier+ exclude surrounding quotes (regardless of whether provided in +string+)
        # +string+ supports the range of schema/table references understood by Hanaclient, for example:
        #
        # * <tt>table_name</tt>
        # * <tt>"table.name"</tt>
        # * <tt>schema_name.table_name</tt>
        # * <tt>schema_name."table.name"</tt>
        # * <tt>"schema_name".table_name</tt>
        # * <tt>"schema.name"."table name"</tt>
        def extract_schema_qualified_name(string)
          schema, table = string.scan(/[^".]+|"[^"]*"/)
          if table.nil?
            table = schema
            schema = nil
          end
          Hanaclient::Name.new(schema, table)
        end

        def unquote_identifier(identifier)
          if identifier && identifier.start_with?('"')
            identifier[1..-2]
          else
            identifier
          end
        end
      end
    end
  end
end