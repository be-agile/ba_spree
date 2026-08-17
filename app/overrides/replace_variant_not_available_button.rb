Deface::Override.new(
  virtual_path: "spree/products/_add_to_cart_button",
  name: "replace_variant_not_available_button",
  replace: "erb[loud]:contains('notify_me_when_available')",
  text: <<-ERB
    <% if product&.discontinued? || selected_variant&.discontinued? %>
      <%= Spree.t(:add_to_cart_discontinued) %>
    <% elsif selected_variant.present? && !selected_variant.purchasable? %>
      <%= Spree.t(:add_to_cart_not_purchasable) %>
    <% else %>
      <%= Spree.t(:add_to_cart_not_available) %>
    <% end %>
  ERB
)

Deface::Override.new(
  virtual_path: "spree/products/_add_to_cart_button",
  name: "remove_variant_not_available_button_bell_icon",
  remove: "erb[loud]:contains('bell')")
