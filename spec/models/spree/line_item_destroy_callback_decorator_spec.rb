# frozen_string_literal: true

require 'rails_helper'

# Issue #1298 への対応。Spree 5.3.6 で `has_many :inventory_units` に `dependent: :destroy` が
# 付いたことで destroy コールバックの順序が反転し、明細削除時に
#   1. 削除対象を指す inventory_unit が作り直されて orphan になる (管理画面の明細削除が 500)
#   2. restock されず在庫が戻らない
# という 2 つの不具合が起きていた。5.1.x と同じ順序に戻っていることを検証する。
RSpec.describe Spree::LineItem, type: :model do
  let!(:store) { Spree::Store.default.persisted? ? Spree::Store.default : create(:store) }

  describe 'before_destroy のコールバック順序' do
    subject(:filters) { described_class._destroy_callbacks.select { |c| c.kind == :before }.map(&:filter) }

    # dependent: :destroy は無名 Proc として登録されるため、
    # verify が先頭にいることで「在庫を戻してから inventory_unit を消す」順序を担保する
    it { is_expected.to start_with(:verify_order_inventory_before_destroy) }
    it { expect(filters.count(:verify_order_inventory_before_destroy)).to eq 1 }
  end

  describe '明細の削除' do
    subject(:destroy_line_item) { Spree.line_item_destroy_service.call(line_item: line_item) }

    let(:stock_item) { line_item.variant.stock_items.first }

    def orphan_inventory_units
      Spree::InventoryUnit.where.missing(:line_item)
    end

    def inventory_unit_ids_of(target_line_item)
      Spree::InventoryUnit.where(line_item_id: target_line_item.id).pluck(:id).sort
    end

    context '完了済みの注文の場合' do
      let(:order) { create(:order_ready_to_ship, line_items_count: 2, with_payment: false) }
      let(:line_item) { order.line_items.first }
      let(:other_line_item) { order.line_items.last }

      it { expect { destroy_line_item }.not_to raise_error }

      it { expect { destroy_line_item }.to change { stock_item.reload.count_on_hand }.by(line_item.quantity) }

      it { expect { destroy_line_item }.to change { inventory_unit_ids_of(line_item) }.to([]) }

      it { expect { destroy_line_item }.not_to change { inventory_unit_ids_of(other_line_item) } }

      it { expect { destroy_line_item }.not_to change(orphan_inventory_units, :count) }

      it 'package の item_total が計算できる状態を保つ' do
        destroy_line_item
        order.reload.shipments.each do |shipment|
          expect { shipment.to_package.item_total }.not_to raise_error
        end
      end
    end

    context '同一 variant の明細が複数ある場合' do
      let(:order) { create(:order_ready_to_ship, line_items_count: 1, with_payment: false) }
      let(:line_item) { order.line_items.first }
      let(:variant) { line_item.variant }
      let(:other_line_item) { order.line_items.reload.find { |li| li != line_item } }

      # spree_embed_gravity_forms が wp_gf_entry_id で line_item を分離するケース (#1187)
      before do
        variant.stock_items.each { |item| item.update!(count_on_hand: 10) }
        create(:line_item, order: order, variant: variant, quantity: 1)
        order.reload
      end

      it { expect { destroy_line_item }.to change { stock_item.reload.count_on_hand }.by(line_item.quantity) }

      it { expect { destroy_line_item }.not_to change { inventory_unit_ids_of(other_line_item) } }

      it { expect { destroy_line_item }.not_to change(orphan_inventory_units, :count) }
    end

    context '未完了の注文 (カート) の場合' do
      let(:order) do
        create(:order_with_line_items, state: 'cart', completed_at: nil,
                                       shipment_state: nil, payment_state: nil)
      end
      let(:line_item) { order.line_items.first }

      it { expect { destroy_line_item }.not_to raise_error }

      # 未完了注文では Spree::OrderInventory#verify が即 return するため在庫は動かない
      it { expect { destroy_line_item }.not_to change { stock_item.reload.count_on_hand } }

      it { expect { destroy_line_item }.not_to change(orphan_inventory_units, :count) }
    end
  end
end
