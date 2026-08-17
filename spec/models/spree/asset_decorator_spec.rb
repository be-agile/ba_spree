# frozen_string_literal: true

require 'rails_helper'

# Issue #1292: 一括アップロード時に position が重複しないよう、acts_as_list の採番より先に
# viewable の行を排他ロックして直列化している。
# @see https://github.com/be-agile/giga-repeat/issues/1292
RSpec.describe Spree::AssetDecorator, type: :model do
  let!(:store) { create(:store, default: true) }
  let(:product) { create(:product, stores: [ store ]) }
  let(:variant) { product.master }

  def assets
    Spree::Asset.unscoped.where(viewable: variant).order(:position, :id)
  end

  def positions
    assets.pluck(:position)
  end

  def ordered_ids
    assets.pluck(:id)
  end

  describe "before_create :lock_position_scope" do
    # 実際の並列 INSERT はテストで再現できないため、ロックが acts_as_list の採番より
    # 先に発行されていること(= 直列化が成立する条件)を SQL の並びで検証する
    def captured_sql
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        statements << payload[:sql]
      end
      yield
      statements
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    subject { captured_sql { create(:image, viewable: variant) } }

    it "viewable の行ロックと採番が INSERT より先に発行される" do
      lock_index = subject.index { |sql| sql.match?(/FOR UPDATE/i) && sql.include?('spree_variants') }
      max_index = subject.index { |sql| sql.match?(/MAX\(.?spree_assets.?\..?position/i) }
      insert_index = subject.index { |sql| sql.match?(/INSERT INTO .?spree_assets/i) }

      expect([ lock_index, max_index, insert_index ]).to all(be_present)
      expect(lock_index).to be < max_index
      expect(max_index).to be < insert_index
    end

    # MySQL の REPEATABLE READ では、行ロックの取得を待っている間に他トランザクションが
    # commit した行が通常の SELECT からは見えない。採番はロック付き読み取りである必要がある。
    it "採番はロック付き読み取りで行う" do
      max_sql = subject.find { |sql| sql.match?(/MAX\(.?spree_assets.?\..?position/i) }

      expect(max_sql).to match(/FOR UPDATE/i)
    end

    context "viewable が未確定(セッション退避アップロード)のとき" do
      subject { captured_sql { create(:image, viewable_type: 'Spree::Variant', viewable_id: nil) } }

      it { expect(subject.none? { |sql| sql.match?(/FOR UPDATE/i) }).to be true }
    end

    context "画像を続けて作成したとき" do
      subject { positions }

      before { 4.times { create(:image, viewable: variant) } }

      it { is_expected.to eq [ 1, 2, 3, 4 ] }
    end
  end

  # 採番を acts_as_list から引き取ったことで、削除時の詰め直し(acts_as_list の
  # decrement_positions_on_lower_items)と噛み合わなくなっていないことを確認する。
  describe "画像の削除・追加" do
    subject { positions }

    let!(:images) { Array.new(5) { create(:image, viewable: variant) } }

    context "中間の画像を削除したとき" do
      before { images[2].destroy }

      it { is_expected.to eq [ 1, 2, 3, 4 ] }
    end

    context "先頭の画像を削除したとき" do
      before { images.first.destroy }

      it { is_expected.to eq [ 1, 2, 3, 4 ] }
      it { expect(ordered_ids).to eq images.drop(1).map(&:id) }
    end

    context "削除してから追加したとき" do
      let!(:added) do
        images[2].destroy
        create(:image, viewable: variant)
      end

      it { is_expected.to eq [ 1, 2, 3, 4, 5 ] }
      it { expect(ordered_ids.last).to eq added.id }
    end
  end
end
