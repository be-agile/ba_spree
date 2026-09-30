require 'rails_helper'

RSpec.describe BaSpree::LineItemDecorator, type: :model do
  describe "#price_stale?" do
    let(:order) { create(:order_with_line_items, line_items_count: 1) }
    let(:line_item) { order.line_items.first }
    let(:current_price) { line_item.variant.price_in(order.currency) }

    # factory の line_item は variant の価格と無関係な price を持つので、address から次へ進んだ状態に揃える
    before { order.update_line_item_prices! }

    subject { line_item.price_stale? }

    context "販売価格が注文時と同じ" do
      it { is_expected.to be false }
    end

    context "販売価格が注文後に変わった" do
      before { current_price.update!(amount: line_item.price + 100) }

      it { is_expected.to be true }
    end
  end
end
