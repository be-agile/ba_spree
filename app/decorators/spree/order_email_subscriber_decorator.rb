module Spree
  # Spree 5.3.6 の注文確認 / 店舗オーナー通知メールが、本番のインスタンス複数台 + Sidekiq 非同期
  # 環境で2通送信される race condition への対策。
  #
  # 本家 OrderEmailSubscriber#send_confirmation_email は
  #   ① return if order.confirmation_delivered?   (チェック)
  #   ② OrderMailer.confirm_email(...).deliver_later (送信)
  #   ③ order.update_column(:confirmation_delivered, true) (フラグ更新)
  # の順で、①〜③が非アトミック。さらに本家は complete 遷移時に order.completed を2回 publish するため
  # (finalize! 内 + after_transition)、2インスタンスが①を同時に false で通過すると②を両方実行し2通になる。
  #
  # 「flag=false の行を true に更新できた1プロセスだけが送信権を得る」条件付き UPDATE 一発に変更し、
  # MySQL の行ロックで直列化することで、同時実行でも送信を1通に絞る。
  # 確認メール / 店舗オーナー通知の両方が同型の race を持つため、両方に適用する。
  #
  # @see https://github.com/be-agile/giga-repeat/issues/1232
  module OrderEmailSubscriberDecorator
    private

    # @gem-override spree_emails-5.3.6/app/subscribers/spree/order_email_subscriber.rb#send_confirmation_email
    # @see https://github.com/be-agile/giga-repeat/issues/1232
    def send_confirmation_email(event)
      order = find_order(event)
      return unless order
      return unless order.store.prefers_send_consumer_transactional_emails?

      # アトミックに false→true を更新できた1プロセスだけが送信する（多重送信防止）
      return if claim_delivery_flag(order, :confirmation_delivered).zero?

      OrderMailer.confirm_email(order.id).deliver_later

      send_store_owner_notification(order) if order.store.new_order_notifications_email.present?
    end

    # @gem-override spree_emails-5.3.6/app/subscribers/spree/order_email_subscriber.rb#send_store_owner_notification
    # @see https://github.com/be-agile/giga-repeat/issues/1232
    def send_store_owner_notification(order)
      return if order.store.new_order_notifications_email.blank?
      return if claim_delivery_flag(order, :store_owner_notification_delivered).zero?

      OrderMailer.store_owner_notification_email(order.id).deliver_later
    end

    # id 指定 + 当該フラグが「未送信」の行を true に更新し、更新できた行数を返す。
    # 同時実行時は MySQL の行ロックで直列化され、勝者のみ 1、それ以外は 0 を得る。
    #
    # 「未送信」は false だけでなく NULL も含める必要がある。
    # store_owner_notification_delivered は upstream スキーマ上 default 未指定 (= NULL) で、
    # 新規注文ではこのカラムが NULL のまま作られる。`column => false` だけだと MySQL の
    # `NULL = FALSE` が真にならず更新0行となり、店舗オーナー通知が永久に送られない (#1241)。
    def claim_delivery_flag(order, column)
      Spree::Order
        .where(id: order.id)
        .where(arel_table[column].eq(false).or(arel_table[column].eq(nil)))
        .update_all(column => true)
    end

    def arel_table
      Spree::Order.arel_table
    end
  end
end

Spree::OrderEmailSubscriber.prepend(Spree::OrderEmailSubscriberDecorator)
