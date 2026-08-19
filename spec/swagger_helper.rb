# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'CRM API V1',
        version: 'v1',
        description: 'Tenant-facing API for the multi-tenant CRM.'
      },
      paths: {},
      components: {
        securitySchemes: {
          profile_session: {
            type: :apiKey,
            in: :cookie,
            name: '_crm_session',
            description: 'Devise session cookie for a signed-in Profile (POST /profiles/sign_in).'
          }
        },
        schemas: {
          channel: {
            type: :object,
            properties: {
              id: { type: :string, format: :uuid },
              type: { type: :string, enum: %w[whatsapp instagram] },
              external_id: { type: :string },
              display_name: { type: :string },
              status: { type: :string, enum: %w[pending connected error disabled] }
            },
            required: %w[id type external_id display_name status]
          },
          errors: {
            type: :object,
            properties: {
              errors: { type: :array, items: { type: :string } }
            }
          }
        }
      },
      servers: [
        {
          url: 'https://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'www.example.com'
            }
          }
        }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
