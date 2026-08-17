module Spree
  module ContactDecorator
    def self.prepended(base)
      base.attribute :mail_from_address, validate: true
    end

    # @gem-override spree_storefront-5.3.6/app/models/spree/contact.rb#headers
    # @see https://github.com/be-agile/giga-repeat/issues/1092
    # 本家は from を問い合わせ者本人のメールにするが、SES 未検証アドレスで 500 になるため
    # from を mail_from_address（検証済み送信元）に変え、本人は reply_to に回す。
    def headers
      {
        subject: 'Contact Us',
        to: customer_support_email.to_s,
        from: mail_from_address,
        reply_to: %("#{name}" <#{email}>)
      }
    end
  end
end

Spree::Contact.prepend Spree::ContactDecorator
