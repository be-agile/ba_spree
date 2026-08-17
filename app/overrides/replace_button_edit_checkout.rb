Deface::Override.new(
  virtual_path: "spree/checkout/edit",
  name: "replace_button_edit_checkout",
  replace: "div.text-xs",
  text: <<-HTML
    <div class="text-xs text-end whitespace-nowrap">
      <%= link_to Spree.t(:edit), spree.checkout_state_path(@order.token, 'address'), class: "btn-secondary !py-1 !font-normal-important !text-xs-important" %>
    </div>
  HTML
)
