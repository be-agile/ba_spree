# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Spree::Contact, type: :model do
  let(:store) { create(:store, mail_from_address: 'store@example.com', customer_support_email: 'support@example.com') }

  before do
    allow(Spree::Store).to receive(:default).and_return(store)
  end

  describe '#headers' do
    let(:contact) do
      Spree::Contact.new(
        name: '山田太郎',
        email: 'yamada@example.com',
        message: 'お問い合わせ内容',
        customer_support_email: store.customer_support_email,
        mail_from_address: store.mail_from_address
      )
    end

    subject { contact.headers }

    it { is_expected.to include(from: 'store@example.com') }
    it { is_expected.to include(to: 'support@example.com') }
    it { is_expected.to include(reply_to: '"山田太郎" <yamada@example.com>') }
    it { is_expected.to include(subject: 'Contact Us') }
  end

  describe '#valid?' do
    let(:contact) do
      Spree::Contact.new(
        name: '山田太郎',
        email: 'yamada@example.com',
        message: 'お問い合わせ内容',
        customer_support_email: store.customer_support_email,
        mail_from_address: mail_from_address
      )
    end

    subject { contact.valid? }

    context 'mail_from_addressがnil' do
      let(:mail_from_address) { nil }

      it { is_expected.to be false }
    end

    context 'mail_from_addressが設定されている' do
      let(:mail_from_address) { 'store@example.com' }

      it { is_expected.to be true }
    end
  end
end
