Deface::Override.new(
  virtual_path: 'spree/shared/_order_details',
  name: 'show_individual_adjustments_in_order_details',
  replace: "erb[silent]:contains('if order.promo_total != 0')",
  closing_selector: "erb[silent]:contains('end'):first",
  text: <<~ERB
    <% sort_adjustments_with_flat_percent_last(order.adjustments.nonzero.non_tax.eligible).each do |adjustment| %>
      <div class="flex items-center justify-between py-2">
        <div>
          <%= adjustment.label %>
        </div>
        <div>
          <%= adjustment.display_amount.to_html %>
        </div>
      </div>
    <% end %>
  ERB
)
