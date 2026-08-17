module BaSpree
  module OrderDecorator
    ASSOCIATED_USER_ATTRIBUTES = [ :user_id, :email, :created_by_id, :bill_address_id, :ship_address_id ]

    # @gem-override spree_core-5.3.6/app/models/spree/order.rb#associate_user!
    # @see https://github.com/be-agile/giga-repeat/commit/d0dbe2b4524e22c1cf974bbd4829c587ef7cd254
    # Associates the specified user with the order.
    def associate_user!(user, override_email = true)
      self.user           = user
      self.email          = user.email if override_email
      # we need to check if user is of admin user class to avoid mismatch type error
      # in a scenario where we have separate classes for admin and regular users
      self.created_by   ||= user if user.is_a?(Spree.admin_user_class)
      self.bill_address ||= user.bill_address
      self.ship_address ||= user.ship_address

      # 未保存(id=nil)の order では where(id: self) が `WHERE id IS NULL` となり、
      # update_all が無関係なレコードを対象にしたり reload が RecordNotFound を投げる。
      # まだ永続化されていない場合はメモリ上の代入のみで十分なので DB 反映はスキップする。
      return self unless persisted?

      changes = slice(*ASSOCIATED_USER_ATTRIBUTES)

      # immediately persist the changes we just made, but don't use save
      # since we might have an invalid address associated
      ActiveRecord::Base.connected_to(role: :writing) do
        self.class.unscoped.where(id: self).update_all(changes)
      end

      # Reload to ensure memory state matches DB state, then recalculate promotions
      reload
      updater.update

      # Spree 5.3 追従: update_all はコールバックを bypass するため order.updated を手動 publish
      publish_event('order.updated') if changes.present?
    end

    # @gem-override spree_core-5.3.6/app/models/spree/order.rb#disassociate_user!
    # @see https://github.com/be-agile/giga-repeat/commit/d0dbe2b4524e22c1cf974bbd4829c587ef7cd254
    def disassociate_user!
      nullified_attributes = ASSOCIATED_USER_ATTRIBUTES.index_with(nil)

      update_columns(nullified_attributes)

      # Reload to ensure memory state matches DB state, then recalculate promotions
      reload
      updater.update
    end

    # @gem-override spree_core-5.3.6/app/models/spree/order.rb#after_cancel
    # @see https://github.com/be-agile/giga-repeat/issues/1001
    # Spree 5.3 追従: 本家追加の publish_order_canceled_event は super で取り込まれる
    # 注文キャンセル時にpending状態のゲートウェイ決済（オーソリ）もキャンセルする
    # Spreeコアは completed のみをキャンセルするが、オーソリのまま残すと以下の問題がある：
    # - 決済プロバイダー側にオーソリが残る
    # - 顧客のカード利用可能額が減少したまま
    # - 後で誤って売上計上される可能性
    def after_cancel
      super

      # pending 状態のゲートウェイ決済（オーソリ）をキャンセル
      # store_credit は Spree コアで処理済みなので除外
      payments.pending.not_store_credits.each do |payment|
        # Gatewayベースの決済方法のみ対象（銀行振込や代引きは除外）
        if payment.payment_method.is_a?(Spree::Gateway)
          payment.cancel!
        end
      end
    end

    # @gem-override spree_core-5.3.6/app/models/spree/order.rb#canceled_by
    # @see https://github.com/be-agile/giga-repeat/issues/1232
    # Spree 5.3.6 本家のバグ修正: canceled_by 末尾の publish_event('order.canceled') は
    # コメント（"Manually publish update event"）通り本来 'order.updated' を publish すべき箇所。
    # 'order.canceled' のままだと、transaction 内の cancel! が after_cancel 経由で既に
    # 'order.canceled' を publish しているのと合わせて二重 publish となり、
    # OrderEmailSubscriber#send_cancel_email がガード無しのためキャンセルメールが2通送信される。
    # update_columns はコールバックを bypass するため、本来意図された 'order.updated' を publish する。
    def canceled_by(user, canceled_at = nil)
      canceled_at ||= Time.current
      changes = { canceler_id: user.id, canceled_at: canceled_at }

      transaction do
        update_columns(changes)
        cancel!
      end

      # Manually publish update event since update_columns bypasses callbacks
      # （cancel! 内の after_cancel が 'order.canceled' を publish 済みなので、ここは update のみ）
      publish_event('order.updated')
    end
  end
end

Spree::Order.prepend(BaSpree::OrderDecorator)
