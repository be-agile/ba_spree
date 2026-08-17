module Spree
  module AdjustmentSourceDecorator
    # @gem-override spree_core-5.3.6/app/models/concerns/spree/adjustment_source.rb#create_unique_adjustment
    # @see https://github.com/be-agile/giga-repeat/issues/1183
    # 並行リクエスト時の重複 adjustment 作成を防ぐため、order を排他ロックしてから
    # 既存チェックと作成を実行する。これがないと、ブラウザ複数タブから同一 order に
    # 同時にカート操作されたとき、`already_adjusted?` の SELECT が両リクエストで
    # false を返し、同じ source の adjustment が二重に INSERT されてしまう。
    def create_unique_adjustment(order, adjustable)
      with_order_lock(order) { super }
    end

    # @gem-override spree_core-5.3.6/app/models/concerns/spree/adjustment_source.rb#create_unique_adjustments
    # @see https://github.com/be-agile/giga-repeat/issues/1183
    def create_unique_adjustments(order, adjustables, &block)
      with_order_lock(order) { super }
    end

    private

    # @gem-override spree_core-5.3.6/app/models/concerns/spree/adjustment_source.rb#already_adjusted?
    # @see https://github.com/be-agile/giga-repeat/issues/1183
    # `already_adjusted?` を locking read (FOR UPDATE) で実行することで、
    # MySQL REPEATABLE READ 下の snapshot 問題を回避する。
    # 通常 SELECT は transaction 開始時の snapshot を見るため、先行 transaction の
    # adjustment INSERT が後続 transaction から見えないケースがあるが、
    # locking read は current read で最新状態を見るため、先行の commit 後の
    # adjustment が必ず見える。
    def already_adjusted?(adjustable)
      adjustments.lock.where(adjustable: adjustable).exists?
    end

    # @gem-override spree_core-5.3.6/app/models/concerns/spree/adjustment_source.rb#already_adjusted_ids
    # @see https://github.com/be-agile/giga-repeat/issues/1183
    # 同上の理由で locking read で実行する。
    def already_adjusted_ids(order)
      adjustments.lock.where(order: order).pluck(:adjustable_id)
    end

    # order インスタンス自体に dirty な属性 (例: last_ip_address) がある状態で
    # `order.with_lock` を呼ぶと Rails 8 では RuntimeError になるため、
    # 別インスタンスで `SELECT ... FOR UPDATE` を発行してロックを取得する。
    # トランザクション内で行リレベルロックを取れば、後続リクエストは
    # 先行トランザクションの commit を待つので race condition は防げる。
    def with_order_lock(order)
      order.class.transaction do
        order.class.lock.where(id: order.id).pluck(:id)
        yield
      end
    end
  end
end

# Spree::AdjustmentSource を include している promotion action 系の各クラスに対して
# decorator を prepend する。concern module 自体に prepend するのではなく include 元クラスに
# 直接適用することで、Ruby のメソッド解決順が確実に decorator を経由するようにする。
# TaxRate は AdjustmentSource を include しているが create_unique_adjustment を経由しないため対象外。
[
  Spree::Promotion::Actions::CreateAdjustment,
  Spree::Promotion::Actions::CreateItemAdjustments,
  Spree::Promotion::Actions::FreeShipping,
  defined?(Spree::Promotion::Actions::CreateVolumeDiscountAdjustments) ? Spree::Promotion::Actions::CreateVolumeDiscountAdjustments : nil,
  defined?(Spree::Promotion::Actions::CreateVolumeBasedOptionFee) ? Spree::Promotion::Actions::CreateVolumeBasedOptionFee : nil
].compact.each do |klass|
  klass.prepend(Spree::AdjustmentSourceDecorator)
end
