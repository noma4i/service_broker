require 'test_helper'

class DuckFilterTest < BrokerTest
  def operation(**)
    declare do
      required { duck(:value, **) }

      def execute
        value
      end
    end
  end

  def test_sb_04_28_declaration_needs_named_methods
    [{}, { methods: [] }, { methods: [:read], class: ::String }].each do |options|
      assert_raises(ServiceBroker::DeclarationError, options.inspect) { operation(**options) }
    end
  end

  def test_sb_04_29_codes_and_default_options
    assert_equal %i[methods nils], ServiceBroker::Filters::Duck.default_options.keys.sort

    checked = operation(methods: %i[read])

    assert_equal :nils, checked.validate(value: nil).errors.symbolic['value']
    assert_equal :duck, checked.validate(value: '').errors.symbolic['value']
    assert_equal '', operation(methods: %i[length]).call(value: '')
  end
end
