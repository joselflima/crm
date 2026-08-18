require 'swagger_helper'

RSpec.describe 'api/v1/channels', type: :request do
  let(:admin) { profiles(:acme_admin) }
  let(:agent) { profiles(:acme_agent) }
  let(:other_admin) { profiles(:globex_admin) }

  path '/api/v1/channels' do
    post('create a WhatsApp or Instagram channel') do
      tags 'Channels'
      description <<~DESC
        Inserts (or updates) the current tenant's WhatsApp or Instagram
        channel and stores the associated API credentials in
        `tenant_secrets`. The access token is encrypted at rest and never
        echoed back in the response.
      DESC
      consumes 'application/json'
      produces 'application/json'
      security [ profile_session: [] ]

      parameter name: :channel, in: :body, schema: {
        type: :object,
        properties: {
          channel: {
            type: :object,
            properties: {
              type: { type: :string, enum: %w[whatsapp instagram], description: 'Channel provider' },
              external_id: { type: :string, description: 'phone_number_id (WhatsApp) or Instagram Business Account ID' },
              access_token: { type: :string, description: 'Meta access token for this channel' },
              phone_number_id: { type: :string, description: 'Required when type is whatsapp' }
            },
            required: %w[type external_id access_token]
          }
        },
        required: %w[channel]
      }

      response(201, 'channel created') do
        schema '$ref' => '#/components/schemas/channel'

        before { sign_in admin }

        let(:channel) do
          { channel: { type: 'whatsapp', external_id: 'phone-123', access_token: 'super-secret-token', phone_number_id: 'phone-123' } }
        end

        run_test! do |response|
          body = response.parsed_body
          expect(body['type']).to eq('whatsapp')
          expect(body['external_id']).to eq('phone-123')
          expect(response.body).not_to include('super-secret-token')

          secret = tenants(:acme).tenant_secret
          expect(secret.whatsapp_access_token).to eq('super-secret-token')
        end
      end

      response(422, 'invalid request') do
        schema '$ref' => '#/components/schemas/errors'

        before { sign_in admin }

        let(:channel) do
          { channel: { type: 'whatsapp', external_id: 'phone-123', phone_number_id: 'phone-123' } }
        end

        run_test!
      end

      response(403, 'forbidden — not a tenant admin') do
        before { sign_in agent }

        let(:channel) do
          { channel: { type: 'whatsapp', external_id: 'phone-999', access_token: 'token', phone_number_id: 'phone-999' } }
        end

        run_test!
      end

      response(401, 'unauthenticated') do
        let(:channel) do
          { channel: { type: 'whatsapp', external_id: 'phone-999', access_token: 'token', phone_number_id: 'phone-999' } }
        end

        run_test!
      end
    end
  end

  describe 'cross-tenant external_id conflicts' do
    it 'rejects an external_id already used by another tenant' do
      sign_in admin
      post '/api/v1/channels', params: {
        channel: { type: 'whatsapp', external_id: 'shared-phone-id', access_token: 'token-a', phone_number_id: 'shared-phone-id' }
      }, as: :json
      expect(response).to have_http_status(:created)
      sign_out admin

      sign_in other_admin
      post '/api/v1/channels', params: {
        channel: { type: 'whatsapp', external_id: 'shared-phone-id', access_token: 'token-b', phone_number_id: 'shared-phone-id' }
      }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'stores the instagram secret and business account id' do
      sign_in admin
      post '/api/v1/channels', params: {
        channel: { type: 'instagram', external_id: 'ig-business-456', access_token: 'ig-secret-token' }
      }, as: :json
      expect(response).to have_http_status(:created)

      secret = tenants(:acme).tenant_secret
      expect(secret.instagram_access_token).to eq('ig-secret-token')
      expect(secret.instagram_business_account_id).to eq('ig-business-456')
    end
  end
end
