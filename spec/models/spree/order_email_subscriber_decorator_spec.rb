# frozen_string_literal: true

require 'rails_helper'

# Spree 5.3.6 の OrderEmailSubscriber は「confirmation_delivered? チェック → 送信 → フラグ更新」が
# 非アトミックで、order.completed の二重 publish と複数インスタンスが重なると確認メールが2通飛ぶ (#1232)。
# ba_spree の override は claim_delivery_flag（条件付き UPDATE 一発）で送信権を1プロセスに絞る。
RSpec.describe Spree::OrderEmailSubscriber, type: :model do
  subject(:subscriber) { described_class.new }

  let(:order) { create(:order, confirmation_delivered: false) }
  let(:store) { order.store }
  # subscriber は event.payload['id'] しか参照しないため、payload を返すだけの double を使う。
  let(:event) { double('event', payload: { 'id' => order.id }) }

  before do
    # preference のセッターは Spree 独自 API のため、参照される判定メソッドを直接スタブする。
    allow_any_instance_of(Spree::Store)
      .to receive(:prefers_send_consumer_transactional_emails?).and_return(true)
  end

  describe '#send_confirmation_email' do
    context 'まだ確認メールを送っていない場合（claim 成功）' do
      it '確認メールを送信し、confirmation_delivered を true にする' do
        allow(Spree::OrderMailer).to receive(:confirm_email).and_return(double(deliver_later: true))

        subscriber.send(:send_confirmation_email, event)

        expect(Spree::OrderMailer).to have_received(:confirm_email).with(order.id)
        expect(order.reload.confirmation_delivered).to be(true)
      end
    end

    context '既に確認メールを送信済みの場合（claim 失敗 = 同時実行の敗者を模擬）' do
      before { order.update_column(:confirmation_delivered, true) }

      it '確認メールを送信しない（多重送信防止）' do
        expect do
          subscriber.send(:send_confirmation_email, event)
        end.not_to have_enqueued_mail(Spree::OrderMailer, :confirm_email)
      end
    end

    context 'store がトランザクションメール送信を無効にしている場合' do
      before do
        allow_any_instance_of(Spree::Store)
          .to receive(:prefers_send_consumer_transactional_emails?).and_return(false)
      end

      it '確認メールを送信しない' do
        expect do
          subscriber.send(:send_confirmation_email, event)
        end.not_to have_enqueued_mail(Spree::OrderMailer, :confirm_email)
      end
    end
  end

  describe '#send_store_owner_notification' do
    before do
      allow(store).to receive(:new_order_notifications_email).and_return('owner@example.com')
      allow(order).to receive(:store).and_return(store)
    end

    context 'まだ店舗通知を送っていない場合（claim 成功）' do
      before { order.update_column(:store_owner_notification_delivered, false) }

      it '店舗通知メールを送信し、store_owner_notification_delivered を true にする' do
        allow(Spree::OrderMailer).to receive(:store_owner_notification_email)
          .and_return(double(deliver_later: true))

        subscriber.send(:send_store_owner_notification, order)

        expect(Spree::OrderMailer).to have_received(:store_owner_notification_email).with(order.id)
        expect(order.reload.store_owner_notification_delivered).to be(true)
      end
    end

    # store_owner_notification_delivered は upstream スキーマ上 default NULL。
    # NULL を未送信として扱えないと店舗オーナー通知が永久に送られない回帰バグ (#1241)。
    context 'store_owner_notification_delivered が NULL の場合（未送信扱い）' do
      before { order.update_column(:store_owner_notification_delivered, nil) }

      it '店舗通知メールを送信し、フラグを true にする' do
        allow(Spree::OrderMailer).to receive(:store_owner_notification_email)
          .and_return(double(deliver_later: true))

        subscriber.send(:send_store_owner_notification, order)

        expect(Spree::OrderMailer).to have_received(:store_owner_notification_email).with(order.id)
        expect(order.reload.store_owner_notification_delivered).to be(true)
      end
    end

    context '既に店舗通知を送信済みの場合（claim 失敗）' do
      before { order.update_column(:store_owner_notification_delivered, true) }

      it '店舗通知メールを送信しない（多重送信防止）' do
        expect do
          subscriber.send(:send_store_owner_notification, order)
        end.not_to have_enqueued_mail(Spree::OrderMailer, :store_owner_notification_email)
      end
    end

    context 'new_order_notifications_email が未設定の場合' do
      before { allow(store).to receive(:new_order_notifications_email).and_return(nil) }

      it '店舗通知メールを送信しない' do
        expect do
          subscriber.send(:send_store_owner_notification, order)
        end.not_to have_enqueued_mail(Spree::OrderMailer, :store_owner_notification_email)
      end
    end
  end

  describe '#claim_delivery_flag' do
    it 'フラグが false の行を true に更新し、更新行数 1 を返す' do
      result = subscriber.send(:claim_delivery_flag, order, :confirmation_delivered)
      expect(result).to eq(1)
      expect(order.reload.confirmation_delivered).to be(true)
    end

    it '既に true の場合は更新せず 0 を返す（同時実行の敗者）' do
      order.update_column(:confirmation_delivered, true)
      result = subscriber.send(:claim_delivery_flag, order, :confirmation_delivered)
      expect(result).to eq(0)
    end

    # store_owner_notification_delivered は upstream スキーマ上 default NULL のため、
    # NULL を未送信として拾えないと店舗オーナー通知が永久に送られない (#1241)。
    it 'フラグが NULL の行も未送信として true に更新し、更新行数 1 を返す' do
      order.update_column(:store_owner_notification_delivered, nil)
      result = subscriber.send(:claim_delivery_flag, order, :store_owner_notification_delivered)
      expect(result).to eq(1)
      expect(order.reload.store_owner_notification_delivered).to be(true)
    end
  end
end
