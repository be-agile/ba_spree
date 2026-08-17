module Spree
  module Stock
    module PackerDecorator
      # 同一 variant の複数 line_item が order に存在する場合 (例: spree_embed_gravity_forms の
      # `wp_gf_entry_id` で line_item を分離するケース) に、Spree 本家の実装では
      # `inventory_units.index_by(&:variant_id)` で 1 つに集約してしまい、最初に作られた
      # line_item の inventory_unit が package に渡らず orphan になる問題への対処。
      # Issue #1187 を参照。
      #
      # 修正方針: variant ごとに qty 合計で fill_status を呼び (本家の在庫判定ロジックを維持)、
      # 結果を line_item 単位で先着順に on_hand / backordered へ按分する。
      # 単純な each 置換では fill_status が読み取り専用 (count_on_hand を減らさない) なため
      # 過剰販売が起きてしまうので、按分配置が必須。
      #
      # @gem-override spree_core-5.3.6/app/models/spree/stock/packer.rb#default_package
      # @see https://github.com/be-agile/giga-repeat/issues/1187
      def default_package
        package = Package.new(stock_location)

        inventory_units.group_by(&:variant_id).each do |variant_id, units_for_variant|
          variant = Spree::Variant.find(variant_id)

          if variant.should_track_inventory?
            next unless stock_location.stocks?(variant)

            total_qty = units_for_variant.sum(&:quantity)
            on_hand, _backordered = stock_location.fill_status(variant, total_qty)

            allocate_units_to_package(package, units_for_variant, on_hand)
          else
            units_for_variant.each { |inventory_unit| package.add(inventory_unit.dup) }
          end
        end

        package
      end

      private

      # variant 単位の fill_status 結果 (on_hand 数) を line_item 単位の inventory_unit に
      # 先着順で配分する。on_hand_remaining を使い切ったら以降は backordered になる。
      def allocate_units_to_package(package, units_for_variant, on_hand)
        on_hand_remaining = on_hand

        units_for_variant.each do |inventory_unit|
          unit = inventory_unit.dup
          qty = inventory_unit.quantity

          unit_on_hand = [ qty, on_hand_remaining ].min
          on_hand_remaining -= unit_on_hand
          unit_backordered = qty - unit_on_hand

          package.add(InventoryUnit.split(unit, unit_backordered), :backordered) if unit_backordered.positive?
          package.add(InventoryUnit.split(unit, unit_on_hand), :on_hand) if unit_on_hand.positive?
        end
      end
    end
  end
end

Spree::Stock::Packer.prepend(Spree::Stock::PackerDecorator)
