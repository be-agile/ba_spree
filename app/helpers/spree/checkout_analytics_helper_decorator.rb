module Spree
  module CheckoutAnalyticsHelperDecorator
    # @gem-override spree_storefront-5.3.6/app/helpers/spree/checkout_analytics_helper.rb#clear_checkout_completed_session
    # reason: 本家のセッションクリア (super) に加え、ゲスト注文の token cookie・signed cookie・
    #   return_to セッションも削除して不要なリダイレクトを防ぐ (commit 5df2e778)
    # @see https://github.com/be-agile/giga-repeat/commit/5df2e7780bcd683db4dfb369edc26c72f73d1d5b
    def clear_checkout_completed_session
      super
      # Clear guest order tokens from cookies
      cookies.delete(:token) if cookies[:token].present?
      cookies.delete(:guest_token) if cookies[:guest_token].present?
      cookies.delete(:order_token) if cookies[:order_token].present?

      # Clear permanent signed tokens
      cookies.permanent.signed[:token] = nil if cookies.permanent.signed[:token].present?
      cookies.permanent.signed[:guest_token] = nil if cookies.permanent.signed[:guest_token].present?
      cookies.permanent.signed[:order_token] = nil if cookies.permanent.signed[:order_token].present?

      # Clear session-based stored locations that cause unwanted redirects
      session.delete("user_return_to") if session["user_return_to"]
      session.delete("#{resource_name}_return_to") if session["#{resource_name}_return_to"]
    end

    private

    def resource_name
      :user
    end
  end
end

Spree::CheckoutAnalyticsHelper.prepend(Spree::CheckoutAnalyticsHelperDecorator)
