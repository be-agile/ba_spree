module Spree
  module Stock
    module PrioritizerDecorator
      # 同一 variant の複数 line_item が order に存在する場合 (例: spree_embed_gravity_forms の
      # `wp_gf_entry_id` で line_item を分離するケース) に、Spree 本家の
      # `hash_item` は shipment が無いと `variant.hash` のみで識別するため、
      # 同 variant の inventory_unit が同じ adjuster を共有してしまい、
      # 後発の inventory_unit が `Adjuster#adjust` の `fulfilled?` 判定で
      # `remove_item` されて shipment から欠落する。
      # Issue #1187 を参照。Packer decorator の修正と合わせて line_item 単位で adjuster を
      # 個別化することで対処する。
      #
      # @gem-override spree_core-5.3.6/app/models/spree/stock/prioritizer.rb#hash_item
      # @see https://github.com/be-agile/giga-repeat/issues/1187
      def hash_item(item)
        line_item_id = item.inventory_unit.line_item_id
        return super unless line_item_id

        shipment = item.inventory_unit.shipment
        base = item.inventory_unit.variant.hash ^ line_item_id.hash
        shipment.present? ? (base ^ shipment.hash) : base
      end
    end
  end
end

Spree::Stock::Prioritizer.prepend(Spree::Stock::PrioritizerDecorator)
