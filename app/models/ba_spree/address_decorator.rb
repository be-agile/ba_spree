module BaSpree
  module AddressDecorator
    def self.prepended(base)
      # NOTE: Spree::Address は Spree 標準で `after_create :set_user_attributes` が設定されており、
      # 配送先・請求先の区別なく Address 作成時に User の名前等が上書きされていたが、
      # 「プレゼント送付先(配送先)の名前で User の本名が上書きされる」問題があったため、
      # Spree 標準の callback そのものを解除する。
      # 代わりに User#bill_address_id 変更時のコールバック(Spree::UserBillAddressSyncDecorator)で
      # 請求先からのみ User 情報を同期するように変更した。
      # raise: false は必須。prepend されたモジュールが再度 prepend されると Ruby は
      # ancestors を変えないままこの prepended フックだけを再実行するため、2回目以降は
      # 解除済みの callback を探して ArgumentError になる。development では
      # engine の activate が to_prepare からリロードのたびに decorator を load し直すので、
      # ガードがないとファイルを1つ編集しただけでリロードが落ちる。
      # @see https://github.com/be-agile/giga-repeat/issues/1307
      base.skip_callback :create, :after, :set_user_attributes, raise: false

      base.after_initialize :set_default_values, if: -> { new_record? && user.present? }
    end

    # @gem-override spree_core-5.3.6/app/models/spree/address.rb#show_company_address_field?
    # @see https://github.com/be-agile/giga-repeat/issues/1165
    # 本家は Store#prefers_company_field_enabled? を見るが、ba_spree では常に会社名欄を表示する。
    # 日本の EC では法人向け配送のため会社名欄が求められることが多いため。
    def show_company_address_field?
      true
    end

    private

    # @gem-override spree_core-5.3.6/app/models/spree/address.rb#set_default_values
    # @see https://github.com/be-agile/giga-repeat/issues/1165
    # 本家の firstname / lastname / phone 補完に加えて company も User から補完する。
    def set_default_values
      self.firstname ||= user.first_name
      self.lastname ||= user.last_name
      self.phone ||= user.phone
      self.company ||= user.company
    end
  end
end

Spree::Address.prepend BaSpree::AddressDecorator
