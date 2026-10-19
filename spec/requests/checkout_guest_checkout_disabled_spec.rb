require 'rails_helper'

# BaSpree::CheckoutControllerDecorator#load_order は本家の load_order を丸ごと再実装している。
# その際に落ちていた「ユーザーが紐付いていないカートは、ゲスト購入が無効なストアでは
# ログインを要求する」分岐を復元したことを担保する（#1352）。
RSpec.describe 'Checkout with guest checkout disabled', type: :request do
  let!(:store) { create(:store, default: true, url: 'test.localhost') }
  # giga-repeat の :order factory は既定で complete のため、チェックアウト対象として
  # incomplete（cart 状態）かつユーザー未紐付けの注文を用意する。
  let(:guest_order) { create(:order, store: store, user: nil, state: 'cart', completed_at: nil) }

  before do
    host! 'test.localhost'
    Rails.cache.delete('default_store')
  end

  subject do
    get "/checkout/#{guest_order.token}"
    response
  end

  context 'guest_checkout ON' do
    it { is_expected.not_to redirect_to(new_user_session_path) }
  end

  context 'guest_checkout OFF' do
    before do
      store.update!(preferred_guest_checkout: false)
      Rails.cache.delete('default_store')
    end

    it { is_expected.to be_redirect }
  end
end
