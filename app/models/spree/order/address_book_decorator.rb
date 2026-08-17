module Spree
  module Order::AddressBookDecorator
    # @gem-override spree_core-5.3.6/app/models/spree/order/address_book.rb#ship_address_attributes=
    # @see https://github.com/be-agile/giga-repeat/commit/e57a39c4
    # 本家との差分は user.reload を挟む点（チェックアップ住所ステップ通過時のデフォルト住所同期ズレ対策）。
    def ship_address_attributes=(attributes)
      self.ship_address = update_or_create_address(attributes)
      user.reload.ship_address = ship_address if should_assign_user_default_address?(ship_address)
      self.ship_address = nil if quick_checkout_address?(attributes[:quick_checkout]) && !ship_address.persisted?
    end
  end
end

Spree::Order::AddressBook.prepend Spree::Order::AddressBookDecorator
