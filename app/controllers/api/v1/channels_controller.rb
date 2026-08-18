module Api
  module V1
    class ChannelsController < Api::BaseController
      before_action :require_tenant_admin!

      # POST /api/v1/channels
      # Inserts (or updates) the tenant's WhatsApp or Instagram channel and
      # stores the associated API credentials in tenant_secrets.
      def create
        type = channel_params[:type]
        errors = validate_channel_params(type)
        return render json: { errors: errors }, status: :unprocessable_entity if errors.any?

        channel = ActiveRecord::Base.transaction do
          upsert_secret!(type)
          upsert_channel!(type)
        end

        render json: channel_json(channel), status: :created
      end

      private

      def validate_channel_params(type)
        errors = []
        errors << "type must be one of #{Channel::TYPES.join(', ')}" unless Channel::TYPES.include?(type)
        errors << "access_token can't be blank" if channel_params[:access_token].blank?
        errors << "external_id can't be blank" if channel_params[:external_id].blank?
        errors << "phone_number_id can't be blank" if type == "whatsapp" && channel_params[:phone_number_id].blank?
        errors
      end

      def require_tenant_admin!
        unless current_tenant.present? && current_profile.admin_or_super_admin?
          render json: { error: "forbidden" }, status: :forbidden
        end
      end

      def channel_params
        params.require(:channel).permit(:type, :external_id, :access_token, :phone_number_id)
      end

      def upsert_channel!(type)
        channel = current_tenant.channels.find_or_initialize_by(
          type: type,
          external_id: channel_params[:external_id]
        )
        channel.status = :active
        channel.save!
        channel
      end

      def upsert_secret!(type)
        secret = current_tenant.tenant_secret || current_tenant.create_tenant_secret!

        case type
        when "whatsapp"
          secret.whatsapp_access_token = channel_params[:access_token]
          secret.whatsapp_phone_number_id = channel_params[:phone_number_id]
        when "instagram"
          secret.instagram_access_token = channel_params[:access_token]
          secret.instagram_business_account_id = channel_params[:external_id]
        end

        secret.save!
      end

      def channel_json(channel)
        {
          id: channel.id,
          type: channel.type,
          external_id: channel.external_id,
          status: channel.status
        }
      end
    end
  end
end
