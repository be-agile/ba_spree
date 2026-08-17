module Spree
  module OrdersControllerDecorator
    # @gem-override spree_storefront-5.3.6/app/controllers/spree/orders_controller.rb#edit
    # reason: 本家 edit (super) の後に、セッション切れで自動ログアウトした場合の order からの
    #   ユーザー紐付け解除と turbo_stream レスポンス対応を追加 (commit d9fb5efc)
    # @see https://github.com/be-agile/giga-repeat/commit/d9fb5efc3b81bd54639e9cbaa04f930098c02835
    def edit
      super

      # Handle automatic logout: if user session expired but order still has user_id
      if try_spree_current_user.nil? && @order&.user_id.present?
        Rails.logger.info "Detected automatic logout for order #{@order.number}, disassociating user"
        @order.disassociate_user!
      end

      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end
  end
end

Spree::OrdersController.prepend Spree::OrdersControllerDecorator
