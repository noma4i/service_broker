require 'rails/railtie'

module ServiceBroker
  # Loads the part that needs ActiveRecord and ActiveJob once Rails is up.
  class Railtie < ::Rails::Railtie
    initializer 'service_broker.rails_part', after: :load_active_support do
      ActiveSupport.on_load(:active_record) do
        require 'service_broker/rails'
      end
    end
  end
end
