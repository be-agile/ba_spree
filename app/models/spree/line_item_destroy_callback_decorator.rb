module Spree
  # 明細(line_item)削除時に、在庫を戻してから inventory_unit を消す順序を保証する。
  #
  # Spree 5.3.6 で `has_many :inventory_units` に `dependent: :destroy` が付いた結果、
  # アソシエーション宣言の時点で登録される before_destroy が
  # `verify_order_inventory_before_destroy` より先に走るようになった。
  # そのため Spree::OrderInventory#verify に到達した時点で inventory_units が 0 件になっており、
  # 「削除」ではなく「追加」に分岐して次の 2 つの不具合が起きる。
  #
  #   1. 削除しようとしている line_item を指す inventory_unit を作り直してしまう。
  #      line_item が消えたあと orphan となり、Spree::Stock::ContentItem#amount が
  #      nil * quantity で NoMethodError を投げる (管理画面の明細削除が 500)
  #   2. remove_from_shipment を通らないため restock されず、逆に unstock される (在庫が戻らない)
  #
  # ActiveSupport::Callbacks は同じシンボルのコールバックを重複排除するため、
  # prepend: true で登録し直すだけで元の登録は取り除かれる (skip_callback は不要)。
  # これにより 5.1.x と同じ順序に戻る。
  #
  # @gem-override spree_core-5.3.6/app/models/spree/line_item.rb
  # @see https://github.com/be-agile/giga-repeat/issues/1298
  module LineItemDestroyCallbackDecorator
    def self.prepended(base)
      base.before_destroy :verify_order_inventory_before_destroy,
                          prepend: true,
                          if: -> { order.has_checkout_step?('delivery') }
    end
  end
end

Spree::LineItem.prepend Spree::LineItemDestroyCallbackDecorator
