module Api
  module V1
    class MeController < BaseController
      def show
        render json: {
          currency: current_user.currency,
          distance_unit: current_user.distance_unit,
          volume_unit: current_user.volume_unit,
          token: { name: current_api_token.name, permission: current_api_token.permission }
        }
      end
    end
  end
end
