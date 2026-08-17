# frozen_string_literal: true

require 'rails_helper'

# Issue #1187 への対応で、Spree::Stock::Packer#default_package を decorate して
# 同一 variant の複数 line_item を line_item 単位で按分して package に配置するロジックの spec。
# spree_embed_gravity_forms が wp_gf_entry_id で line_item を分離するケースに対応する。
RSpec.describe Spree::Stock::Packer, type: :model do
  subject(:packer) { described_class.new(stock_location, inventory_units) }

  let!(:store) { Spree::Store.default.persisted? ? Spree::Store.default : create(:store) }
  let!(:stock_location) { Spree::StockLocation.first || create(:stock_location, propagate_all_variants: false) }
  let(:variant) { create(:variant) }

  # Spree::Stock::InventoryUnitBuilder と同じ形で生成 (= shipment 紐付け前の inventory_unit)
  def build_inventory_unit(variant:, quantity:, line_item_id: nil)
    Spree::InventoryUnit.new(variant: variant, quantity: quantity, line_item_id: line_item_id)
  end

  # stock_location と variant の組み合わせの stock_item は variant 作成時の after_create
  # で自動伝播される実装になっており、再度 propagate_variant を呼ぶと unique 制約で落ちる。
  # ここでは既存 stock_item を取得して count_on_hand と backorderable を直接 update する。
  def set_stock(variant, count_on_hand:, backorderable: false)
    stock_item = stock_location.stock_items.find_by(variant: variant) ||
                 stock_location.stock_items.create!(variant: variant)
    stock_item.update!(count_on_hand: count_on_hand, backorderable: backorderable)
  end

  describe '#default_package' do
    context '同一 variant の line_item が複数ある場合' do
      let(:inventory_units) do
        [
          build_inventory_unit(variant: variant, quantity: 1, line_item_id: 1001),
          build_inventory_unit(variant: variant, quantity: 1, line_item_id: 1002)
        ]
      end

      context '在庫が充足している場合 (count_on_hand=10)' do
        before { set_stock(variant, count_on_hand: 10) }

        subject(:package) { packer.default_package }

        it 'すべての line_item が on_hand に配置される' do
          expect(package.on_hand.size).to eq(2)
          expect(package.backordered.size).to eq(0)
        end

        it 'line_item_id が個別に保持される' do
          line_item_ids = package.on_hand.map { |item| item.inventory_unit.line_item_id }
          expect(line_item_ids).to contain_exactly(1001, 1002)
        end
      end

      context '在庫が 1 個しかなく backorderable=true の場合' do
        before { set_stock(variant, count_on_hand: 1, backorderable: true) }

        subject(:package) { packer.default_package }

        it '先着 line_item は on_hand、後発は backordered になる (過剰販売しない)' do
          expect(package.on_hand.size).to eq(1)
          expect(package.backordered.size).to eq(1)
        end

        it '先着 line_item が on_hand を獲得する' do
          on_hand_line_item_id = package.on_hand.first.inventory_unit.line_item_id
          backordered_line_item_id = package.backordered.first.inventory_unit.line_item_id
          expect(on_hand_line_item_id).to eq(1001)
          expect(backordered_line_item_id).to eq(1002)
        end
      end

      context 'qty が 1 より大きく按分の境界をまたぐ場合 (count_on_hand=3, qty=2+2)' do
        let(:inventory_units) do
          [
            build_inventory_unit(variant: variant, quantity: 2, line_item_id: 1001),
            build_inventory_unit(variant: variant, quantity: 2, line_item_id: 1002)
          ]
        end

        before { set_stock(variant, count_on_hand: 3, backorderable: true) }

        subject(:package) { packer.default_package }

        it '先着 line_item に在庫を優先配分し、足りない分が backordered になる' do
          on_hand_qty = package.on_hand.sum { |item| item.inventory_unit.quantity }
          backordered_qty = package.backordered.sum { |item| item.inventory_unit.quantity }
          expect(on_hand_qty).to eq(3)
          expect(backordered_qty).to eq(1)
        end
      end
    end

    context '異なる variant の line_items が混在する場合 (regression)' do
      let(:variant_a) { create(:variant) }
      let(:variant_b) { create(:variant) }
      let(:inventory_units) do
        [
          build_inventory_unit(variant: variant_a, quantity: 2, line_item_id: 2001),
          build_inventory_unit(variant: variant_b, quantity: 3, line_item_id: 2002)
        ]
      end

      before do
        set_stock(variant_a, count_on_hand: 5, backorderable: false)
        set_stock(variant_b, count_on_hand: 0, backorderable: true)
      end

      subject(:package) { packer.default_package }

      it 'variant_a は全数 on_hand、variant_b は全数 backordered になる' do
        on_hand_qty = package.on_hand.sum { |item| item.inventory_unit.quantity }
        backordered_qty = package.backordered.sum { |item| item.inventory_unit.quantity }
        expect(on_hand_qty).to eq(2)
        expect(backordered_qty).to eq(3)
      end
    end

    context 'track_inventory=false の variant の場合 (regression)' do
      let(:non_tracked_variant) { create(:variant, track_inventory: false) }
      let(:inventory_units) do
        [
          build_inventory_unit(variant: non_tracked_variant, quantity: 1, line_item_id: 3001),
          build_inventory_unit(variant: non_tracked_variant, quantity: 1, line_item_id: 3002)
        ]
      end

      subject(:package) { packer.default_package }

      it 'fill_status を呼ばずに inventory_unit がそのまま package に追加される' do
        expect(stock_location).not_to receive(:fill_status)
        expect(package.contents.size).to eq(2)
      end
    end

    context '単一 line_item (Gravity Form 未使用) の場合 (regression)' do
      let(:inventory_units) do
        [ build_inventory_unit(variant: variant, quantity: 1, line_item_id: 4001) ]
      end

      before { set_stock(variant, count_on_hand: 10) }

      subject(:package) { packer.default_package }

      it 'inventory_unit が 1 件だけ on_hand に配置される' do
        expect(package.on_hand.size).to eq(1)
        expect(package.backordered.size).to eq(0)
      end
    end
  end
end
