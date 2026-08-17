# frozen_string_literal: true

require 'rails_helper'

# Issue #1292: 商品画像を並び替えても元に戻ってしまう問題への対応。
# position が 1..N の連番でないと acts_as_list が周囲を詰め直さないため、
# 並び替えの前に連番へ詰め直す。
# @see https://github.com/be-agile/giga-repeat/issues/1292
RSpec.describe Spree::Assets::PositionNormalizer, type: :model do
  let!(:store) { create(:store, default: true) }
  let(:product) { create(:product, stores: [ store ]) }
  let(:variant) { product.master }
  let!(:images) { Array.new(4) { create(:image, viewable: variant) } }

  # 詰め直しの入力となる position を acts_as_list を通さずに作る
  def break_positions(positions)
    images.each_with_index { |image, index| image.update_column(:position, positions[index]) }
  end

  def ordered_ids
    Spree::Asset.unscoped.where(viewable: variant).order(:position, :id).pluck(:id)
  end

  def positions
    Spree::Asset.unscoped.where(viewable: variant).order(:position, :id).pluck(:position)
  end

  describe ".call" do
    subject { described_class.call(viewable_type: 'Spree::Variant', viewable_id: variant.id) }

    context "すでに 1..N の連番のとき" do
      it { is_expected.to be false }
      it { expect { subject }.not_to change { positions } }
    end

    context "欠番があるとき" do
      before { break_positions([ 1, 2, 5, 20 ]) }

      it { is_expected.to be true }
      it { expect { subject }.to change { positions }.to([ 1, 2, 3, 4 ]) }
      it { expect { subject }.not_to change { ordered_ids } }
    end

    context "重複があるとき" do
      before { break_positions([ 1, 1, 2, 2 ]) }

      it { is_expected.to be true }
      it { expect { subject }.to change { positions }.to([ 1, 2, 3, 4 ]) }

      # 重複していた組の中は id 昇順に確定する
      it { expect { subject }.not_to change { ordered_ids }.from(images.map(&:id)) }
    end

    context "viewable_id が nil のとき" do
      subject { described_class.call(viewable_type: 'Spree::Variant', viewable_id: nil) }

      it { is_expected.to be false }
    end
  end

  describe ".broken_scopes" do
    subject { described_class.broken_scopes }

    context "すべて 1..N の連番のとき" do
      it { is_expected.to be_empty }
    end

    context "欠番があるとき" do
      before { break_positions([ 1, 2, 3, 5 ]) }

      it { is_expected.to eq [ [ 'Spree::Variant', variant.id ] ] }
    end

    context "重複があるとき" do
      before { break_positions([ 1, 1, 2, 3 ]) }

      it { is_expected.to eq [ [ 'Spree::Variant', variant.id ] ] }
    end
  end

  # 管理画面の並び替え(stimulus-sortable)は「画面上のインデックス+1」を送るだけなので、
  # Spree::Admin::AssetsControllerDecorator は詰め直してから本家の更新に渡している。
  # ここではその2ステップが意図どおりの並び順になることを検証する。
  describe "並び替えとの組み合わせ" do
    # 画面上の index 番目(0始まり)の画像を to_index 番目へ動かす
    def sort_to(index, to_index)
      described_class.call(viewable_type: 'Spree::Variant', viewable_id: variant.id)
      Spree::Asset.unscoped.where(viewable: variant).order(:position, :id).to_a[index]
                  .update!(position: to_index + 1)
    end

    context "欠番・重複があるとき" do
      before { break_positions([ 1, 1, 5, 20 ]) }

      it "先頭を末尾へ動かせる" do
        before_ids = ordered_ids
        sort_to(0, 3)
        expect(ordered_ids).to eq [ before_ids[1], before_ids[2], before_ids[3], before_ids[0] ]
        expect(positions).to eq [ 1, 2, 3, 4 ]
      end

      it "末尾を先頭へ動かせる" do
        before_ids = ordered_ids
        sort_to(3, 0)
        expect(ordered_ids).to eq [ before_ids[3], before_ids[0], before_ids[1], before_ids[2] ]
        expect(positions).to eq [ 1, 2, 3, 4 ]
      end

      it "中間を中間へ動かせる" do
        before_ids = ordered_ids
        sort_to(1, 2)
        expect(ordered_ids).to eq [ before_ids[0], before_ids[2], before_ids[1], before_ids[3] ]
        expect(positions).to eq [ 1, 2, 3, 4 ]
      end
    end

    context "もともと 1..N の連番のとき" do
      it "従来どおり並び替えできる" do
        before_ids = ordered_ids
        sort_to(0, 3)
        expect(ordered_ids).to eq [ before_ids[1], before_ids[2], before_ids[3], before_ids[0] ]
        expect(positions).to eq [ 1, 2, 3, 4 ]
      end
    end
  end
end
