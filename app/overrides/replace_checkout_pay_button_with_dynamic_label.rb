Deface::Override.new(
  virtual_path: 'spree/checkout/_payment_methods',
  name: 'replace_checkout_pay_button_with_dynamic_label',
  replace: "#checkout-payment-submit erb[loud]:contains('Spree.t(:pay)')",
  text: <<-ERB
    <% if @order.confirm? %>
      <%= Spree.t(:confirm_order).titleize %>
    <% elsif @order.payment? %>
      <%= Spree.t(:save_and_continue).titleize %>
    <% else %>
      <%= Spree.t(:pay).titleize %>
    <% end %>
  ERB
)
