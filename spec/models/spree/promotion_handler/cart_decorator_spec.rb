require 'spec_helper'

RSpec.describe Spree::PromotionHandler::Cart, type: :model do
  let!(:store) { create(:store) }
  let(:order) { create(:order, store: store, state: 'cart', completed_at: nil) }
  let(:promotion) { create(:promotion, kind: :automatic, code: nil, stores: [ store ]) }

  subject { described_class.new(order).send(:promotions) }

  before do
    rule = Spree::Promotion::Rules::Product.create!(promotion: promotion, preferred_match_policy: 'any')
    rule.product_ids = [ create(:product).id ]
  end

  context '商品ルールの商品がカートに無い場合' do
    it { is_expected.not_to include(promotion) }
  end

  context '商品ルールの商品がカートに無くても、注文に紐づいている場合' do
    before { order.promotions << promotion }

    it { is_expected.to include(promotion) }
  end
end
