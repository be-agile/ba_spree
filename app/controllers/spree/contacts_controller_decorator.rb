module Spree
  module ContactsControllerDecorator
    # @gem-override spree_storefront-5.3.6/app/controllers/spree/contacts_controller.rb#create
    # reason: お問い合わせ自動応答の From が問い合わせ者本人になり SES 未検証エラーで 500 になる問題への対処。
    #   super なし丸ごと再実装で mail_from_address を store の検証済みアドレスに設定する (Issue #1092)
    # @see https://github.com/be-agile/giga-repeat/issues/1092
    def create
      @contact = Spree::Contact.new(params[:contact])
      @contact.customer_support_email = current_store.customer_support_email
      @contact.mail_from_address = current_store.mail_from_address
      @contact.request = request

      if @contact.deliver
        flash[:success] = Spree.t('storefront.contacts.message_sent')
      else
        message_not_sent
      end
      redirect_to action: :new
    end
  end
end

Spree::ContactsController.prepend Spree::ContactsControllerDecorator
