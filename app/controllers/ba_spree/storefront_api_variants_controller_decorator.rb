module BaSpree
  # storefront API のバリエーション取得も、商品と同じ公開状態の判定に揃える
  # （draft / archived / 論理削除済みの商品の SKU・価格が取得できていた）。
  #
  # scope の返り値は Spree::Variant のリレーションで、for_user は Spree::Product の
  # スコープのため後ろにチェーンできない。商品を引く側に挟む必要があるので、
  # 本家のメソッドを丸ごと再実装している。
  module StorefrontApiVariantsControllerDecorator
    private

    # @gem-override spree_api-5.3.6/app/controllers/spree/api/v2/storefront/variants_controller.rb#scope
    # reason: 本家の product_scope に for_user を挟むため。for_user は Spree::Product の
    #   スコープで、本家の返り値(Spree::Variant のリレーション)にはチェーンできない。
    # @see https://github.com/be-agile/giga-repeat/issues/1352
    def scope(skip_cancancan: false)
      product_scope = Spree::Product.for_store(current_store)
      product_scope = product_scope.accessible_by(current_ability, :show) unless skip_cancancan
      product_scope = product_scope.for_user(spree_current_user)
      product_scope = product_scope.i18n if model_class.include?(Spree::TranslatableResource)

      product = product_scope.friendly.find(params[:id])
      product.variants_including_master
    end
  end
end

Spree::Api::V2::Storefront::VariantsController.prepend(BaSpree::StorefrontApiVariantsControllerDecorator)
