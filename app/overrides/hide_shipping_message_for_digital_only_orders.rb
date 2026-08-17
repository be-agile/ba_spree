# Hide shipping confirmation message for digital-only orders
# For digital products, there is no physical shipment, so the message
# "When your order is ready, you will receive an email confirmation"
# should not be displayed.
# See: https://github.com/be-agile/giga-repeat/issues/1006
Deface::Override.new(
  virtual_path: "spree/checkout/complete",
  name: "hide_shipping_message_for_digital_only_orders",
  replace: "erb[loud]:contains('order_success_message')",
  text: <<~ERB
    <% unless @order.digital? %>
      <%= Spree.t('storefront.checkout.order_success_message') %>
    <% end %>
  ERB
)
