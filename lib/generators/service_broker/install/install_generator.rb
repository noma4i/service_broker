require 'rails/generators/base'

module ServiceBroker
  module Generators
    # Writes one settings file into the application.
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def copy_settings_file
        template 'service_broker.rb', 'config/initializers/service_broker.rb'
      end
    end
  end
end
