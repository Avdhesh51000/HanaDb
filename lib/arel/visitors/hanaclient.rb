module Arel
  module Visitors
    class Hanaclient < Arel::Visitors::ToSql
      private
        def visit_Arel_Nodes_As o, collector
          collector = visit o.left, collector
          collector << " AS "
          # The alias must be quoted
          o.right = Arel::Nodes::SqlLiteral.new(quote_column_name(o.right.to_s)) if o.right.instance_of?(Arel::Nodes::SqlLiteral)
          visit o.right, collector
        end
    end
  end
end
