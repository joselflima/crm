require "test_helper"

module Api
  module V1
    class ChannelsControllerTest < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers

      setup do
        @admin = profiles(:acme_admin)
        @agent = profiles(:acme_agent)
        @other_admin = profiles(:globex_admin)
      end

      test "admin creates a whatsapp channel and stores the secret" do
        sign_in @admin

        post api_v1_channels_path, params: {
          channel: {
            type: "whatsapp",
            external_id: "phone-123",
            access_token: "super-secret-token",
            phone_number_id: "phone-123"
          }
        }, as: :json

        assert_response :created

        body = response.parsed_body
        assert_equal "whatsapp", body["type"]
        assert_equal "phone-123", body["external_id"]
        assert_nil body["access_token"]
        refute_includes response.body, "super-secret-token"

        secret = tenants(:acme).tenant_secret
        assert_equal "super-secret-token", secret.whatsapp_access_token

        raw_column = ActiveRecord::Base.connection.select_value(
          "SELECT whatsapp_access_token FROM tenant_secrets WHERE id = #{secret.id}"
        )
        refute_includes raw_column.to_s, "super-secret-token"
      end

      test "admin creates an instagram channel and stores the secret" do
        sign_in @admin

        post api_v1_channels_path, params: {
          channel: {
            type: "instagram",
            external_id: "ig-business-456",
            access_token: "ig-secret-token"
          }
        }, as: :json

        assert_response :created
        secret = tenants(:acme).tenant_secret
        assert_equal "ig-secret-token", secret.instagram_access_token
        assert_equal "ig-business-456", secret.instagram_business_account_id
      end

      test "missing access_token returns 422" do
        sign_in @admin

        post api_v1_channels_path, params: {
          channel: { type: "whatsapp", external_id: "phone-123", phone_number_id: "phone-123" }
        }, as: :json

        assert_response :unprocessable_entity
      end

      test "external_id already used by another tenant returns 422" do
        sign_in @admin
        post api_v1_channels_path, params: {
          channel: {
            type: "whatsapp",
            external_id: "shared-phone-id",
            access_token: "token-a",
            phone_number_id: "shared-phone-id"
          }
        }, as: :json
        assert_response :created

        sign_out @admin
        sign_in @other_admin
        post api_v1_channels_path, params: {
          channel: {
            type: "whatsapp",
            external_id: "shared-phone-id",
            access_token: "token-b",
            phone_number_id: "shared-phone-id"
          }
        }, as: :json

        assert_response :unprocessable_entity
      end

      test "non-admin is forbidden" do
        sign_in @agent

        post api_v1_channels_path, params: {
          channel: {
            type: "whatsapp",
            external_id: "phone-999",
            access_token: "token",
            phone_number_id: "phone-999"
          }
        }, as: :json

        assert_response :forbidden
      end

      test "unauthenticated request is unauthorized" do
        post api_v1_channels_path, params: {
          channel: {
            type: "whatsapp",
            external_id: "phone-999",
            access_token: "token",
            phone_number_id: "phone-999"
          }
        }, as: :json

        assert_response :unauthorized
      end
    end
  end
end
