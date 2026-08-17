module Spree
  # User の bill_address(請求先)が確定したタイミングで、
  # User の first_name / last_name / phone / company を bill_address から同期する。
  #
  # 配送先(ship_address)が「贈り先」であるケースを考慮し、
  # 配送先からは User 情報を更新しないようにするための仕組み。
  module UserBillAddressSyncDecorator
    def self.prepended(base)
      base.after_update :sync_attributes_from_bill_address,
                        if: :saved_change_to_bill_address_id?
    end

    private

    def sync_attributes_from_bill_address
      return unless bill_address

      # 名前は未入力の場合のみコピー(既に入力済みの名前は上書きしない)
      if name.blank?
        self.first_name = bill_address.firstname
        self.last_name = bill_address.lastname
      end

      # phone / company は User 側に値があれば守る(name と方針を揃える)
      self.phone = phone.presence || bill_address.phone
      self.company = company.presence || bill_address.company

      save! if changed?
    end
  end
end

Spree.user_class.prepend(Spree::UserBillAddressSyncDecorator)
