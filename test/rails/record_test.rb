require 'rails_helper'

class RecordFilterTest < RailsBrokerTest
  def operation(**)
    declare do
      required { record(:target, **) }

      def execute
        target
      end
    end
  end

  def code(input, **)
    operation(**).validate(target: input).errors.symbolic['target']
  end

  def test_sb_08_17_takes_a_record_a_global_id_and_a_type_with_an_id
    account = Probe::Account.create!(title: 'a')

    assert_equal account, operation.call(target: account)
    assert_equal account, operation.call(target: account.to_global_id.to_s)
    assert_equal account, operation.call(target: { type: 'Probe::Account', id: account.id })
  end

  def test_sb_08_18_in_option_limits_the_classes_before_any_query
    note = Probe::Note.create!(body: 'b')
    checked = operation(in: [::Probe::Account])
    queries = 0
    counter = ->(*) { queries += 1 }

    outcome = ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      checked.validate(target: { type: 'Probe::Note', id: note.id })
    end

    assert_equal :in, outcome.errors.symbolic['target']
    assert_equal 0, queries
    assert_equal :in, code(note.to_global_id.to_s, in: [::Probe::Account])
  end

  def test_sb_08_19_error_codes
    account = Probe::Account.create!(title: 'a')

    assert_equal :nils, code(nil)
    assert_equal :empty, code('')
    assert_equal :record, code('not-a-gid')
    assert_equal :record, code({ id: account.id })
    assert_equal :record, code({ type: 'Probe::Missing', id: 1 })
    assert_equal :record, code('gid://probe/Probe::Missing/1')
    assert_equal :record, code(42)
    assert_equal :not_found, code({ type: 'Probe::Account', id: account.id + 1_000 })
    assert_equal %i[in nils], ServiceBroker::Filters::Record.default_options.keys.sort
  end
end
