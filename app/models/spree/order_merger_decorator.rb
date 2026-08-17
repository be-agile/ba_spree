module Spree
  module OrderMergerDecorator
    # @gem-override spree_core-5.3.6/app/models/spree/order_merger.rb#merge!
    # @see https://github.com/be-agile/giga-repeat/commit/d0dbe2b4524e22c1cf974bbd4829c587ef7cd254
    def merge!(other_order, user = nil, discard_merged: true)
      other_order.line_items.each do |other_order_line_item|
        next unless other_order_line_item.currency == order.currency

        current_line_item = find_matching_line_item(other_order_line_item)
        handle_merge(current_line_item, other_order_line_item)
      end

      set_user(user)
      clear_addresses(other_order) if discard_merged
      persist_merge

      if discard_merged
        # So that the destroy doesn't take out line items which may have been re-assigned
        other_order.line_items.reload
        other_order.destroy
      else
        other_order.line_items.reload
        other_order.updater.update
      end
    end
  end
end

Spree::OrderMerger.prepend(Spree::OrderMergerDecorator)
