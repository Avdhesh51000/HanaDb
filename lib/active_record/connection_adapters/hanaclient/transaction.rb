module ActiveRecord
  module ConnectionAdapters
    module Hanaclient
      class TransactionManager < ActiveRecord::ConnectionAdapters::TransactionManager
        def begin_transaction(options = {})
          @connection.lock.synchronize do
            run_commit_callbacks = !current_transaction.joinable?
            # HANA does not support savepoints
            transaction = RealTransaction.new(@connection, options, run_commit_callbacks: run_commit_callbacks)

            @stack.push(transaction)
            transaction
          end
        end
      end
    end
  end
end
