module ActiveRecord
  module ConnectionAdapters
    module Hanaclient
      class TypeMetadata < DelegateClass(SqlTypeMetadata)
        def initialize(type_metadata)
          super(type_metadata)
          @type_metadata = type_metadata
        end

        def ==(other)
          other.is_a?(Hanaclient::TypeMetadata) &&
            attributes_for_hash == other.attributes_for_hash
        end
        alias eql? ==

        def hash
          attributes_for_hash.hash
        end

        protected

          def attributes_for_hash
            [self.class, @type_metadata]
          end

      end
    end
  end
end
