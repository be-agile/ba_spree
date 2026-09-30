module BaSpree
  module LineItemDecorator
    # 注文に写し取った price が、現在の販売価格(Spree::LineItem#update_price と同じ計算)とずれているか。
    # 価格の再計算は address から次へ進むときにしか走らないため、チェックアウトを長期間放置した注文で
    # 商品価格(予約割引の終了・価格改定)が変わったことを検知するのに使う。
    # @see https://github.com/be-agile/giga-repeat/issues/1392
    def price_stale?
      context = Spree::Pricing::Context.from_order(variant, order, quantity: quantity)
      variant.price_for(context).price_including_vat_for(tax_zone: tax_zone) != price
    end
  end
end

Spree::LineItem.prepend(BaSpree::LineItemDecorator)
