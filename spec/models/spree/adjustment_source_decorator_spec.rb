# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spree::AdjustmentSourceDecorator, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:line_item) { order.line_items.first }

  describe '#create_unique_adjustment' do
    let(:promotion) { create(:promotion, :with_order_adjustment, code: 'TESTPROMO', weighted_order_adjustment_amount: 100) }
    let(:action) { promotion.actions.first }

    subject { action.send(:create_unique_adjustment, order, order) }

    context '単一リクエストで呼ばれた場合' do
      it 'adjustment が 1 件作成される' do
        expect { subject }.to change { order.all_adjustments.where(source: action).count }.from(0).to(1)
      end
    end

    context '同一 order に対して連続 2 回呼ばれた場合' do
      before { subject }

      it '2 回目は重複作成されない' do
        expect { subject }.not_to change { order.all_adjustments.where(source: action).count }
      end
    end

    context 'order に対して排他ロックを取得する' do
      it 'SELECT ... FOR UPDATE が発行される' do
        queries = []
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
          queries << payload[:sql] if payload[:sql]
        end
        begin
          subject
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end
        expect(queries.any? { |sql| sql.include?('FOR UPDATE') && sql.include?('spree_orders') }).to be true
      end
    end

    context '異なる source の promotion が併用される場合' do
      let(:other_promotion) { create(:promotion, :with_order_adjustment, code: 'OTHERPROMO', weighted_order_adjustment_amount: 200) }
      let(:other_action) { other_promotion.actions.first }

      it '両方の adjustment が作成される' do
        action.send(:create_unique_adjustment, order, order)
        other_action.send(:create_unique_adjustment, order, order)
        expect(order.all_adjustments.where(source: action).count).to eq(1)
        expect(order.all_adjustments.where(source: other_action).count).to eq(1)
      end
    end

    # AT-5: 並列リクエスト下での race condition 防止の論理的根拠を検証する。
    # Thread を直接起動した spec は本体アプリの transactional fixtures と
    # 衝突するため、ここではクエリレベルで以下を確認することで、
    # 並列下でも重複 adjustment が作られないことの論理的保証を担保する。
    #
    # (a) SELECT ... FOR UPDATE が already_adjusted? の "1 AS one" SELECT より先に走る
    #     → 後発リクエストは先発の commit を待ってから既存チェックを行う
    # (b) already_adjusted? の SELECT 自体も FOR UPDATE (locking read) で走る
    #     → MySQL REPEATABLE READ の snapshot 問題を回避し、commit 後の最新状態を見る
    context '並列安全性の論理的保証 (クエリ順序)' do
      let(:queries) { [] }

      before do
        @subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
          queries << payload[:sql] if payload[:sql]
        end
        subject
      end

      after { ActiveSupport::Notifications.unsubscribe(@subscriber) }

      it 'ロック取得が既存チェックより先に走る' do
        # ロック取得 SQL: SELECT id FROM spree_orders WHERE id=? FOR UPDATE
        lock_idx = queries.index { |sql| sql.include?('FOR UPDATE') && sql.include?('spree_orders') }
        # already_adjusted? の SQL: SELECT 1 AS one FROM spree_adjustments WHERE ... LIMIT 1
        check_idx = queries.index do |sql|
          sql.include?('1 AS one FROM `spree_adjustments`') &&
            sql.include?("`source_id` = #{action.id}")
        end
        expect(lock_idx).not_to be_nil
        expect(check_idx).not_to be_nil
        expect(lock_idx).to be < check_idx
      end

      it 'already_adjusted? も FOR UPDATE で走る (REPEATABLE READ snapshot 問題の回避)' do
        check_query = queries.find do |sql|
          sql.include?('1 AS one FROM `spree_adjustments`') &&
            sql.include?("`source_id` = #{action.id}")
        end
        expect(check_query).not_to be_nil
        expect(check_query).to include('FOR UPDATE')
      end
    end
  end

  describe '#create_unique_adjustments' do
    let(:promotion) { create(:promotion, :with_line_item_adjustment, code: 'ITEMPROMO', adjustment_rate: 10) }
    let(:action) { promotion.actions.first }

    subject { action.send(:create_unique_adjustments, order, order.line_items) }

    context '単一リクエストで呼ばれた場合' do
      it '各 line_item に対して adjustment が 1 件ずつ作成される' do
        expect { subject }.to change { order.all_adjustments.where(source: action).count }.by(order.line_items.count)
      end
    end

    context '同一 order に対して連続 2 回呼ばれた場合' do
      before { subject }

      it '2 回目は重複作成されない' do
        expect { subject }.not_to change { order.all_adjustments.where(source: action).count }
      end
    end

    context 'order に対して排他ロックを取得する' do
      it 'SELECT ... FOR UPDATE が発行される' do
        queries = []
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
          queries << payload[:sql] if payload[:sql]
        end
        begin
          subject
        ensure
          ActiveSupport::Notifications.unsubscribe(subscriber)
        end
        expect(queries.any? { |sql| sql.include?('FOR UPDATE') && sql.include?('spree_orders') }).to be true
      end
    end
  end
end
