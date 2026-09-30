require 'rails_helper'

RSpec.describe Spree::CheckoutController, type: :controller do
  routes { Spree::Core::Engine.routes }

  describe "before_action :ensure_line_item_prices_current" do
    let(:user) { create(:user) }
    # spec/support/factory_extensions.rb の :order は完了済みがデフォルトなので、未完了の注文にする
    let(:order) do
      create(:order_with_line_items, user: user, state: state, completed_at: nil, payment_state: nil, shipment_state: nil)
    end
    let(:line_item) { order.line_items.first }
    let(:current_price) { line_item.variant.price_in(order.currency) }

    before do
      allow(controller).to receive(:try_spree_current_user).and_return(user)
      # factory の line_item は variant の価格と無関係な price を持つので、address から次へ進んだ状態に揃える
      order.update_line_item_prices!
      order.update_with_updater!
      create(:check_payment, order: order, amount: order.total)
    end

    shared_context "販売価格が変わった" do
      before { current_price.update!(amount: line_item.price + 100) }
    end

    shared_examples "住所入力からやり直させる" do
      it do
        subject
        # 実際の redirect 先には storefront の locale prefix (/ja) が付くので、helper でも明示する
        expect(response).to redirect_to(Spree::Core::Engine.routes.url_helpers.checkout_state_path(order.token, 'address', locale: 'ja'))
        expect(flash[:error]).to eq Spree.t(:line_item_prices_changed)
        expect(order.reload.state).to eq 'address'
      end
    end

    describe "GET edit" do
      subject { get :edit, params: { token: order.token, state: state } }

      context "confirm で価格が変わった" do
        let(:state) { 'confirm' }

        include_context "販売価格が変わった"

        it_behaves_like "住所入力からやり直させる"
      end

      context "delivery で価格が変わった" do
        let(:state) { 'delivery' }

        include_context "販売価格が変わった"

        it_behaves_like "住所入力からやり直させる"
      end

      context "confirm で価格が同じ" do
        let(:state) { 'confirm' }

        it do
          subject
          expect(response).to have_http_status(:ok)
          expect(order.reload.state).to eq 'confirm'
        end
      end

      context "address で価格が変わった" do
        let(:state) { 'address' }

        include_context "販売価格が変わった"

        it do
          subject
          expect(response).to have_http_status(:ok)
          expect(order.reload.state).to eq 'address'
        end
      end
    end

    describe "PATCH update" do
      subject { patch :update, params: { token: order.token, state: state } }

      context "confirm で価格が変わってから注文を確定した" do
        let(:state) { 'confirm' }

        include_context "販売価格が変わった"

        it_behaves_like "住所入力からやり直させる"

        it { expect { subject }.not_to change { order.reload.completed_at }.from(nil) }
      end
    end
  end
end
