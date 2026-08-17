Deface::Override.new(
  virtual_path: 'spree/checkout/_payment_method',
  name: 'show_only_selected_payment_method_on_confirm',
  replace: "erb[loud]:contains(\"link_to spree.checkout_state_path\")",
  closing_selector: "erb[silent]:contains(\"end\")",
  text: <<~ERB
    <% if @order.state == 'confirm' %>
      <% if selected_method == method %>
        <%= link_to spree.checkout_state_path(token: @order.token, state: 'payment', payment_method_id: method.id),
                    class: 'custom-control custom-radio flex items-center px-5 py-4 cursor-pointer w-full' do %>
          <%= radio_button_tag "order[payments_attributes][][payment_method_id]",
                method.id,
                selected_method == method,
                class: 'mr-3' %>
          <%= Spree.t(method.name, scope: :payment_methods, default: method.name) %>
        <% end %>
      <% end %>
    <% else %>
      <%= link_to spree.checkout_state_path(token: @order.token, state: 'payment', payment_method_id: method.id),
                  class: 'custom-control custom-radio flex items-center px-5 py-4 cursor-pointer w-full' do %>
        <%= radio_button_tag "order[payments_attributes][][payment_method_id]",
              method.id,
              selected_method == method,
              class: 'mr-3' %>
        <%= Spree.t(method.name, scope: :payment_methods, default: method.name) %>
      <% end %>
    <% end %>
  ERB
)
