module Spree
  module Admin
    module UsersControllerDecorator
      # 本家 Spree::Admin::UsersController#search は query.length < 3 で検索を弾くため、
      # 2文字の日本語姓(例: 大村)で検索できなかった。ba_spree では2文字以上で
      # 検索できるよう最小文字数を 2 に緩和する。それ以外の挙動は本家を踏襲する。
      def search
        query = params[:q]&.strip

        head :ok and return if query.blank? || query.length < 2

        scope = model_class.accessible_by(current_ability, :index)
        scope = scope.where.not(id: params[:omit_ids].split(',')) if params[:omit_ids].present?
        @users = scope.includes(:bill_address, :ship_address, avatar_attachment: :blob)
                      .multi_search(query)
                      .limit(params[:limit] || 10)

        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace(
                "users_search_results",
                partial: "spree/admin/users/search_results",
                locals: { users: @users }
              )
            ]
          end
        end
      end
    end
  end
end

Spree::Admin::UsersController.prepend(Spree::Admin::UsersControllerDecorator)
