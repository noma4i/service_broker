require 'rails_helper'
require 'rails/generators'
require 'generators/service_broker/install/install_generator'
require 'fileutils'

class GeneratorTest < RailsBrokerTest
  DESTINATION = File.expand_path('../../tmp/generator', __dir__)

  def setup
    super
    FileUtils.rm_rf(DESTINATION)
    FileUtils.mkdir_p(DESTINATION)
  end

  def test_sb_08_04_install_creates_one_settings_file
    ServiceBroker::Generators::InstallGenerator.start([], destination_root: DESTINATION)

    created = Dir.glob("#{DESTINATION}/**/*").select { |path| File.file?(path) }

    assert_equal ["#{DESTINATION}/config/initializers/service_broker.rb"], created

    body = File.read(created.first)

    ServiceBroker::Configuration::SETTINGS.each do |setting|
      assert_includes body, setting.to_s
    end
  end
end
