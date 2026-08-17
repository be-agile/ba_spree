module BaSpree
  module OrderUpdaterDecorator
    # @gem-override spree_core-5.3.6/app/models/spree/order_updater.rb#update_adjustment_total
    # @see https://github.com/be-agile/giga-repeat/issues/909
    # super 後に order-level adjustment に対する内税計算を追加する。
    # Spree 5.3 追従: 本家の sum→pick 単一クエリ最適化は super 経由で取り込まれるため
    #                 override 本体は無変更(super の結果を部分的に上書きする設計のため互換)。
    def update_adjustment_total
      super

      order.adjustments.tax.where(adjustable_type: 'Spree::Order').destroy_all

      rates = Spree::TaxRate.match(order.tax_zone)
      rates.each do |rate|
        rate.adjust_order_level_adjustments(order)
      end

      order.included_tax_total = line_items.sum(:included_tax_total) +
                                 shipments.sum(:included_tax_total) +
                                 adjustments.tax.eligible.where(adjustable_type: 'Spree::Order').sum(:amount)
      # 0より小さいとvalidateエラーになるため
      order.included_tax_total = 0 if order.included_tax_total.negative?

      order.adjustment_total = line_items.sum(:adjustment_total) +
                              shipments.sum(:adjustment_total) +
                              adjustments.eligible.non_tax.sum(:amount)

      update_order_total
    end
  end
end

Spree::OrderUpdater.prepend(BaSpree::OrderUpdaterDecorator)
