module BaSpree
  # 価格表(price_list)解決の上書きのみを担う decorator。ba_spree には association / slug 生成を
  # 担う BaSpree::ProductDecorator も別にあるため、同一定数にならないよう名前を分けている。
  # @gem-override spree_core-5.3.6/app/models/spree/product.rb#lowest_price, #on_sale?, #price_varies?
  # reason: 本家のこれら3メソッドは prices_including_master (-> { non_zero } のみ) を直接走査し、
  #   pricing context (user / customer_group / price_list の status) を一切考慮しない。
  #   そのため価格表(price_list)機能で以下の不具合が起きる (Issue #1219, Spree 5.4 でも未修正):
  #     - 草案(draft)の price_list でも一覧・関連商品で最安値が表示される
  #     - ゲストや顧客グループ外ユーザにも、他グループ向けの安い単価が一覧で表示される
  #     - 「価格」と「価格で比較」の両方設定で、対象外ユーザにもセールラベルが表示される
  #   商品詳細の本体価格は price_for(Resolver 経由) で正しく解決されているため、一覧・関連・
  #   ラベルでも同じ Resolver を通すよう上書きする。user は Spree::Current.pricing_user
  #   (store_controller_decorator が before_action で設定) から取得する。
  #
  #   ただし Resolver を variant ごとに呼ぶと多 variant 商品で描画が極端に重くなるため、
  #   解決処理は Spree::Pricing::BatchResolver に切り出してバッチ化・メモ化してある (Issue #1290)。
  #   BatchResolver は Resolver の選択規則を複製しているので、Spree アップグレード時は
  #   BatchResolver 側の @gem-override マーカーも確認すること。
  # @see https://github.com/be-agile/giga-repeat/issues/1219
  # @see https://github.com/be-agile/giga-repeat/issues/1290
  module ProductPricingDecorator
    # 指定通貨における最安価格(ログイン中ユーザに適用される price_list を考慮)
    # @param currency [String]
    # @return [Spree::Price, nil]
    def lowest_price(currency)
      resolved_prices_for(currency).min_by(&:amount)
    end

    # 複数 variant 間で(ユーザに適用される)価格が異なるか
    # @param currency [String]
    # @return [Boolean]
    def price_varies?(currency)
      resolved_prices_for(currency).map(&:amount).uniq.size > 1
    end

    # いずれかの variant が(ユーザに適用される価格で)セール中か
    # @param currency [String]
    # @return [Boolean]
    def on_sale?(currency)
      resolved_prices_for(currency).any?(&:discounted?)
    end

    private

    # 全 variant(master 含む)について、現在のユーザに適用される実価格を解決して返す。
    # 解決そのものは Spree::Pricing::BatchResolver に委譲し、ここでは (通貨, ユーザ) 単位で
    # メモ化して lowest_price / price_varies? / on_sale? からの重複解決を防ぐ。
    # @param currency [String]
    # @return [Array<Spree::Price>]
    def resolved_prices_for(currency)
      currency = currency&.upcase
      user = Spree::Current.pricing_user
      cache = (@resolved_prices_for ||= {})
      key = [ currency, user&.id ]
      return cache[key] if cache.key?(key)

      cache[key] = Spree::Pricing::BatchResolver.new(
        variants: variants_including_master.to_a,
        context: Spree::Pricing::Context.new(variant: master, currency: currency, user: user)
      ).resolve
    end
  end
end

Spree::Product.prepend(BaSpree::ProductPricingDecorator)
