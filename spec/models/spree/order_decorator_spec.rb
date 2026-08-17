# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spree::Order, type: :model do
  describe '#after_cancel' do
    # 検証対象は payment_method.is_a?(Spree::Gateway) での分岐なので、
    # ゲートウェイであれば種類は問わない。ba_spree の依存だけで完結させるため、
    # spree_gmo_pg の factory ではなく spree_core の Bogus を使う。
    let(:order) { create(:order_with_line_items, state: 'complete') }
    let(:payment_method) { create(:credit_card_payment_method) }
    let(:credit_card) { create(:credit_card, user: nil) }

    context 'pending状態のゲートウェイ決済がある場合' do
      let!(:pending_payment) do
        create(:payment,
               order: order,
               payment_method: payment_method,
               source: credit_card,
               amount: order.total,
               state: 'pending',
               response_code: 'auth_123')
      end

      it 'pending決済もキャンセルされる' do
        order.cancel!
        expect(pending_payment.reload.state).to eq('void')
      end

      it 'payment_method.voidが呼ばれる（Spree 5.2.0のコア処理）' do
        expect_any_instance_of(Spree::Gateway::Bogus).to receive(:void).with(
          pending_payment.response_code,
          pending_payment.source,
          anything
        ).and_call_original
        order.cancel!
        expect(pending_payment.reload.state).to eq('void')
      end
    end

    context 'completed状態のゲートウェイ決済がある場合' do
      let!(:completed_payment) do
        create(:payment,
               order: order,
               payment_method: payment_method,
               source: credit_card,
               amount: order.total,
               state: 'completed',
               response_code: 'auth_123')
      end

      it 'Spreeコアによってキャンセルされる' do
        order.cancel!
        expect(completed_payment.reload.state).to eq('void')
      end
    end

    context 'pending状態の非ゲートウェイ決済がある場合' do
      let(:check_payment_method) { create(:check_payment_method) }
      let!(:pending_check_payment) do
        create(:check_payment,
               order: order,
               payment_method: check_payment_method,
               amount: order.total,
               state: 'pending')
      end

      it 'キャンセルされない（銀行振込などはゲートウェイではない）' do
        expect(pending_check_payment).not_to receive(:cancel!)
        order.cancel!
      end
    end

    context 'pending決済が複数ある場合' do
      let!(:pending_payment1) do
        create(:payment,
               order: order,
               payment_method: payment_method,
               source: credit_card,
               amount: order.total / 2,
               state: 'pending',
               response_code: 'auth_1')
      end

      let!(:pending_payment2) do
        create(:payment,
               order: order,
               payment_method: payment_method,
               source: credit_card,
               amount: order.total / 2,
               state: 'pending',
               response_code: 'auth_2')
      end

      it 'すべてキャンセルされる' do
        order.cancel!
        expect(pending_payment1.reload.state).to eq('void')
        expect(pending_payment2.reload.state).to eq('void')
      end
    end
  end

  describe '#canceled_by' do
    let(:order) { build_stubbed(:order, state: 'complete') }
    # canceled_by は user.id しか参照しないため、id を持つだけの double を使う。
    let(:admin) { instance_double(Spree.admin_user_class, id: 999) }

    before do
      # canceled_by 自身の publish ロジックだけを検証するため、cancel! / update_columns /
      # transaction の副作用はスタブする。cancel! 内の after_cancel が publish する
      # 'order.canceled' は別途 cancel! のスタブ内で明示的に発火させる。
      allow(order).to receive(:update_columns)
      allow(order).to receive(:cancel!) { order.publish_event('order.canceled') }
    end

    # 本家 canceled_by は末尾でも 'order.canceled' を publish しており、cancel! の after_cancel
    # 経由の publish と二重化してキャンセルメールが2通飛んでいた (#1232)。
    # 1回の canceled_by で 'order.canceled' は1回だけ publish されること（=メール1通）を担保する。
    it "'order.canceled' を1回だけ publish する" do
      published = []
      allow(order).to receive(:publish_event) { |name, *_| published << name }

      order.canceled_by(admin)

      expect(published.count('order.canceled')).to eq(1)
    end

    it "末尾では 'order.updated' を publish する（本家の 'order.canceled' 再publishを修正）" do
      published = []
      allow(order).to receive(:publish_event) { |name, *_| published << name }

      order.canceled_by(admin)

      expect(published).to include('order.updated')
    end

    it 'canceler_id と canceled_at を更新する' do
      expect(order).to receive(:update_columns).with(hash_including(canceler_id: admin.id))
      allow(order).to receive(:publish_event)

      order.canceled_by(admin)
    end
  end
end
