module BaSpree
  module StoreControllerDecorator
    def self.prepended(base)
      base.helper_method :stored_location
      # Issue #1219: 価格表(price_list)を一覧・関連・セールラベルでログイン中ユーザの
      #   グループに反映させるため、リクエスト毎に pricing_user を Spree::Current へ設定する。
      #   Product#lowest_price / #on_sale? / #price_varies? (product_decorator) がこれを参照する。
      base.before_action :set_current_pricing_user
    end

    protected

    # @see https://github.com/be-agile/giga-repeat/issues/1219
    # ログイン中ユーザを Spree::Current.pricing_user に設定する。ゲストは nil。
    def set_current_pricing_user
      Spree::Current.pricing_user = try_spree_current_user
    end

    # @gem-override spree_storefront-5.3.6/app/controllers/spree/store_controller.rb#stored_location
    # reason: ゲストログイン導線で protected な stored_location を helper_method として使えるようにするため
    #   super なしで再実装（実装内容は本家とほぼ同一）(commit d0dbe2b4)
    # @see https://github.com/be-agile/giga-repeat/commit/d0dbe2b4524e22c1cf974bbd4829c587ef7cd254
    def stored_location
      return unless defined?(after_sign_in_path_for)
      return unless defined?(Devise)

      path = after_sign_in_path_for(Devise.mappings.keys.first)
      store_location(path)
      path
    end

    # @gem-override spree_storefront-5.3.6/app/controllers/spree/store_controller.rb#storefront_products_includes
    # reason: カテゴリ詳細でオプションを含む商品がヒットすると落ちる問題への対処。本家の
    #   `option_types` を `option_types_for_includes` に置き換えて eager load する (Issue #847)
    # @see https://github.com/be-agile/giga-repeat/issues/847
    #
    # Spree 5.3 追従: 本家は明示 includes を最小ハッシュに簡略化し、呼び出し元の
    #   `preload_associations_lazily`(ar_lazy_preload)で残りを遅延 preload する方式に移行した。
    #   本家の新ハッシュ構造をベースにしつつ、#847 対策の option_types_for_includes 明示 eager load を維持する。
    def storefront_products_includes
      {
        taxons: [],
        master: [ :images, :prices, { stock_items: :stock_location } ],
        variants: [ :images, :prices, { stock_items: :stock_location } ],
        # Issue #1290: 一覧の価格表示(product_decorator#resolved_prices_for)は
        #   variants_including_master の価格を走査するため、ページ単位でまとめて eager load する
        variants_including_master: [ :prices ],
        # Issue #847: option_types を order(:id) 付き別 association に置き換えて eager load
        option_types_for_includes: []
      }
    end
  end
end

Spree::StoreController.prepend(BaSpree::StoreControllerDecorator)
