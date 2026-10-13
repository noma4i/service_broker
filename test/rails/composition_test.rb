require 'rails_helper'

class RailsCompositionTest < RailsBrokerTest
  def writing_step
    declare do
      required { string :title }

      def execute
        ::Probe::Account.create!(title: title)
      end
    end
  end

  def test_sb_14_09_after_runs_once_the_transaction_commits
    step_class = writing_step
    seen = []
    operation = declare do
      after step_class, title: 'after'
      define_method(:execute) do
        ::Probe::Account.create!(title: 'inside')
        seen << ::Probe::Account.count
        :done
      end
    end

    assert_equal :done, operation.call(safe: true)
    assert_equal [1], seen
    assert_equal %w[inside after], Probe::Account.order(:id).pluck(:title)
  end

  def test_sb_14_09_after_is_skipped_when_the_transaction_rolls_back
    step_class = writing_step
    operation = declare do
      after step_class, title: 'after'

      def execute
        ::Probe::Account.create!(title: 'inside')
        raise ArgumentError, 'boom'
      end
    end

    assert_raises(ArgumentError) { operation.call(safe: true) }

    assert_equal 0, Probe::Account.count
  end

  def test_sb_14_09_in_transaction_step_rolls_back_with_the_operation
    step_class = writing_step
    operation = declare do
      after step_class, title: 'after', in_transaction: true

      def execute
        ::Probe::Account.create!(title: 'inside')
      end

      private

      def validate
        add_error(:base, :rejected) if ::Probe::Account.where(title: 'stop').exists?
      end
    end

    Probe::Account.create!(title: 'stop')

    operation.call(safe: true, soft: true)

    assert_equal %w[stop], Probe::Account.order(:id).pluck(:title)
  end

  def test_sb_14_11_async_after_enqueues_one_job
    ServiceBroker.config.async_runner = ServiceBroker::ActiveJobAsync.new
    step_class = Probe::Media::BuildThumbnail
    operation = declare do
      after step_class, async: true, width: 100

      def execute
        ::Probe::Account.create!(title: 'inside')
      end
    end

    operation.call

    assert_equal 1, enqueued_jobs.size
  end
end
