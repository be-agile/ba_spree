# frozen_string_literal: true

require 'rails_helper'

# Issue #1187 への対応で、Spree::Stock::Prioritizer#hash_item を decorate して
# 同一 variant の inventory_unit でも line_item_id が異なれば別の adjuster に
# マッピングされるようにする (= 後発 inventory_unit が remove されない) ことの spec。
RSpec.describe Spree::Stock::Prioritizer, type: :model do
  let!(:store) { Spree::Store.default.persisted? ? Spree::Store.default : create(:store) }
  let(:variant) { create(:variant) }

  describe '#hash_item' do
    let(:prioritizer) { described_class.new([]) }
    let(:item_a) { instance_double(Spree::Stock::ContentItem, inventory_unit: inventory_unit_a) }
    let(:item_b) { instance_double(Spree::Stock::ContentItem, inventory_unit: inventory_unit_b) }

    context '同一 variant・異なる line_item_id の inventory_unit の場合' do
      let(:inventory_unit_a) do
        Spree::InventoryUnit.new(variant: variant, line_item_id: 5001, shipment: nil)
      end
      let(:inventory_unit_b) do
        Spree::InventoryUnit.new(variant: variant, line_item_id: 5002, shipment: nil)
      end

      it '異なる hash 値が返り、別の adjuster にマッピングされる' do
        hash_a = prioritizer.send(:hash_item, item_a)
        hash_b = prioritizer.send(:hash_item, item_b)
        expect(hash_a).not_to eq(hash_b)
      end
    end

    context '同一 variant・同一 line_item_id の inventory_unit の場合' do
      let(:inventory_unit_a) do
        Spree::InventoryUnit.new(variant: variant, line_item_id: 5001, shipment: nil)
      end
      let(:inventory_unit_b) do
        Spree::InventoryUnit.new(variant: variant, line_item_id: 5001, shipment: nil)
      end

      it '同じ hash 値が返る' do
        hash_a = prioritizer.send(:hash_item, item_a)
        hash_b = prioritizer.send(:hash_item, item_b)
        expect(hash_a).to eq(hash_b)
      end
    end

    context 'line_item_id が nil の場合 (regression: Spree本家の挙動を維持)' do
      let(:inventory_unit_a) do
        Spree::InventoryUnit.new(variant: variant, line_item_id: nil, shipment: nil)
      end
      let(:inventory_unit_b) do
        Spree::InventoryUnit.new(variant: variant, line_item_id: nil, shipment: nil)
      end

      it 'variant.hash を返す (本家フォールバック)' do
        hash_a = prioritizer.send(:hash_item, item_a)
        hash_b = prioritizer.send(:hash_item, item_b)
        expect(hash_a).to eq(variant.hash)
        expect(hash_a).to eq(hash_b)
      end
    end
  end
end
