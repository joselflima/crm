module Api
  class BaseController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :authenticate_profile!

    respond_to :json

    rescue_from ActiveRecord::RecordInvalid do |exception|
      render json: { errors: exception.record.errors.full_messages }, status: :unprocessable_content
    end

    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "not found" }, status: :not_found
    end
  end
end
