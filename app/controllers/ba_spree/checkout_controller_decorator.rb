module BaSpree
  module CheckoutControllerDecorator
    def self.prepended(base)
      base.before_action :filter_bill_address_when_use_shipping, only: [ :update ], if: -> { params[:state] == 'payment' }
      base.before_action :ensure_line_item_prices_current, only: [ :edit, :update ]
    end

    protected

    # Overrides Spree::CheckoutController#load_order to support guest checkout and custom order handling.
    # @gem-override spree_storefront-5.3.6/app/controllers/spree/checkout_controller.rb#load_order
    # reason: ゲストチェックアウト対応のため super なしで丸ごと再実装。本家のゲスト処理を
    #   handle_guest_checkout / create_guest_order に抽出している (commit d0dbe2b4)
    #   #1352: 抽出時に落ちていた本家の `elsif !current_store.prefers_guest_checkout?` →
    #   `require_user(redirect_path: spree_signup_path)` の分岐を復元した。
    #   これが無いと guest_checkout を OFF にしてもゲストのカートがチェックアウトへ進めてしまう。
    # @see https://github.com/be-agile/giga-repeat/commit/d0dbe2b4524e22c1cf974bbd4829c587ef7cd254
    def load_order
      return @order if @order.present?

      orders_scope = action_name == 'complete' ? current_store.orders.complete : current_store.orders.incomplete

      # we shouldn't lock the order here, because we're not going to update it
      lock = ![ 'complete', 'edit' ].include?(action_name)

      @order = orders_scope.lock(lock).find_by(token: params[:token])

      if @order.nil?
        clear_order_token
        redirect_to_cart and return
      end

      if @order.user_id.present?
        if try_spree_current_user.present? && @order.user_id != try_spree_current_user.id
          clear_order_token
          flash[:error] = 'You cannot access this checkout'
          redirect_to_cart
        elsif try_spree_current_user.nil? && !allow_access_to_complete_order_with_new_user?
          handle_guest_checkout
        end
      elsif !current_store.prefers_guest_checkout?
        # 本家にある分岐。ユーザーが紐付いていない（＝純粋なゲストの）カートは、
        # ゲスト購入が無効なストアではログインを要求する。
        # @see https://github.com/be-agile/giga-repeat/issues/1352
        require_user(redirect_path: spree_signup_path)
      end

      # completed orders shouldn't be updated anymore
      unless @order.completed?
        # 5.3 追従: order_tracking_params のうち実際に変化した値だけを更新する
        tracking_params = order_tracking_params
        changed_params = tracking_params.reject { |key, value| @order.public_send(key) == value }

        if changed_params.any?
          @order.assign_attributes(changed_params)
          @order.update_columns(changed_params)
        end

        @order.associate_user!(try_spree_current_user) if try_spree_current_user && @order.user.nil?
      end
      @current_order = @order # for compatibility with the rest of storefront, analytics, etc
    end

    private

    # @gem-override spree_storefront-5.3.6/app/controllers/spree/checkout_controller.rb#allow_access_to_complete_order_with_new_user?
    # reason: ba_spree のゲスト購入は注文確定時に guest ユーザー(guest: true)を
    #   自動作成して order.user_id に紐付ける(app/models/spree/order_decorator.rb#link_guest_user)。
    #   このため本家の判定(signup_for_an_account? 必須)だとゲストが注文完了画面を開けず
    #   ログイン画面にリダイレクトされてしまう。注文に紐付くユーザーが guest の場合は
    #   トークンが一致していれば完了画面の閲覧を許可する。
    def allow_access_to_complete_order_with_new_user?
      return true if super
      return false unless @order.completed? && @order.user_id.present?

      # ゲスト購入で紐付けた guest ユーザー(guest: true)の注文は、URL の order token で
      # アクセスできれば本人とみなして完了画面の閲覧を許可する。
      # (load_order が find_by(token: params[:token]) で URL トークン一致を保証済み。
      #  本家は cookies.signed[:token] 一致も要求するが、ゲストでは確定後のリダイレクトで
      #  cookie が引き継がれないケースがあり、cookie には依存しない)
      # guest ユーザーは link_guest_user で deleted_at が設定される(論理削除)ため
      # with_deleted で取得して判定する。
      guest_user = Spree.user_class.with_deleted.find_by(id: @order.user_id)
      guest_user&.guest? || false
    end

    def handle_guest_checkout
      if params[:guest] && current_store.prefers_guest_checkout?
        @order = create_guest_order
        reset_session
        create_token_cookie(@order.token)
        redirect_to spree.checkout_path(@order.token)
      else
        store_location
        redirect_to spree_login_path
      end
    end

    def create_guest_order
      current_store.orders.create!(current_order_params.except(:token, :user_id)).tap do |order|
        order.merge!(@order, discard_merged: false)
        order.disassociate_user!
      end
    end

    # チェックアウトを放置している間に商品価格が変わっていたら、住所入力からやり直させる。
    # address から次へ進むときに Spree が明細価格を再計算し、続く配送・支払ステップで
    # 送料・税・支払金額が現在価格で作り直される。
    # @see https://github.com/be-agile/giga-repeat/issues/1392
    def ensure_line_item_prices_current
      # 価格の再計算が走るのは address から次へ進むときだけなので、それより後の state だけ判定する
      return unless %w[delivery payment confirm].include?(@order.state)
      return unless @order.line_item_prices_stale?

      @order.restart_checkout_flow
      flash[:error] = Spree.t(:line_item_prices_changed)
      redirect_to spree.checkout_state_path(@order.token, 'address')
    end

    def filter_bill_address_when_use_shipping
      return unless params[:order]&.dig(:bill_address_attributes)

      if params[:order]&.dig(:use_shipping) == '1'
        # Remove bill_address_attributes entirely when use_shipping is enabled
        params[:order].delete(:bill_address_attributes)
      elsif params[:order]&.dig(:use_shipping) == '0'
        # Remove id field to force new address creation when use_shipping is disabled
        params[:order][:bill_address_attributes].delete(:id) if params[:order][:bill_address_attributes][:id]
      end
    end
  end
end

Spree::CheckoutController.prepend(BaSpree::CheckoutControllerDecorator)
