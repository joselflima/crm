require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Crm
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # The database carries triggers (trg_*_updated_at) and functions
    # (set_updated_at, transfer_to_human) that schema.rb cannot express, so it
    # silently dropped them from the test database. Dump SQL instead.
    config.active_record.schema_format = :sql

    # RSpec is this app's test framework (see spec/, rswag request specs).
    config.generators do |g|
      g.test_framework :rspec, fixtures: true, request_specs: true
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
