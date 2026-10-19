module BaSpree
  # storefront API の商品取得を、HTML 側と同じ公開状態の判定に揃える。
  #
  # 本家の scope は for_store + accessible_by(:show) だけで、ゲストに適用される
  # Spree::PermissionSets::DefaultCustomer が `can :read, Spree::Product` を条件なしで
  # 与えるため、公開状態の絞り込みが効いていない。結果、slug か id を指定すれば
  # draft(非公開) / archived(取扱対象外) / 論理削除済みの商品が取得できていた。
  #
  # 一覧も同じ scope を通るので、filter[show_discontinued] / filter[show_deleted] を
  # 渡してフィルタを外す経路もここで塞がる（for_user が付ける status = 'active' は
  # finder の include_discontinued では外れず、not_deleted は生 SQL の where なので
  # with_deleted の unscope でも消えない）。
  #
  # prepend 先は storefront のコントローラに限定する。Spree::Api::V2::ResourceController に
  # 当てると、それを継承する Spree::Api::V2::Platform::ResourceController 経由で
  # Platform API 全体が Spree::Variant 等に for_user を呼んで NoMethodError になる。
  #
  # @see https://github.com/be-agile/giga-repeat/issues/1352
  module StorefrontApiProductsControllerDecorator
    protected

    def scope(skip_cancancan: false)
      super.for_user(spree_current_user)
    end
  end
end

Spree::Api::V2::Storefront::ProductsController.prepend(BaSpree::StorefrontApiProductsControllerDecorator)
