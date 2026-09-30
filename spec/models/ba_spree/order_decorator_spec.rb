require 'rails_helper'

RSpec.describe BaSpree::OrderDecorator, type: :model do
  describe "#line_item_prices_stale?" do
    let(:order) { create(:order_with_line_items, line_items_count: 2) }

    # factory の line_item は variant の価格と無関係な price を持つので、address から次へ進んだ状態に揃える
    before { order.update_line_item_prices! }

    subject { order.line_item_prices_stale? }

    context "全明細の販売価格が注文時と同じ" do
      it { is_expected.to be false }
    end

    context "1明細だけ販売価格が変わった" do
      before do
        line_item = order.line_items.last
        line_item.variant.price_in(order.currency).update!(amount: line_item.price + 100)
      end

      it { is_expected.to be true }
    end
  end
end
