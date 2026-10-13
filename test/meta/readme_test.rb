require 'test_helper'
require 'service_broker/testing'

class ReadmeTest < BrokerTest
  ROOT = File.expand_path('../..', __dir__)

  def readme
    @readme ||= File.read(File.join(ROOT, 'README.md'))
  end

  def test_sb_10_12_readme_names_every_setting
    ServiceBroker::Configuration::SETTINGS.each do |setting|
      assert_includes readme, "`#{setting}`", setting.to_s
    end
  end

  def test_sb_10_12_readme_names_every_input_type_and_call_option
    require 'service_broker/rails/filters/finder'
    require 'service_broker/rails/filters/model'
    require 'service_broker/rails/filters/gid'
    ServiceBroker::Filters.replace(:finder, ServiceBroker::Filters::Finder)
    ServiceBroker::Filters.replace(:model, ServiceBroker::Filters::Model)
    ServiceBroker::Filters.replace(:gid, ServiceBroker::Filters::Gid)

    ServiceBroker::Filters.names.each do |type|
      assert_includes readme, "| `#{type}` |", type.to_s
    end

    ServiceBroker::Operation::EXECUTION_OPTIONS.each do |option|
      assert_includes readme, "| `#{option}` |", option.to_s
    end
  end

  def test_sb_10_12_readme_names_every_helper
    ServiceBroker::Testing.instance_methods(false).each do |helper|
      assert_includes readme, helper.to_s, helper.to_s
    end
  end
end
