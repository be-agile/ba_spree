Deface::Override.new(
  virtual_path: 'spree/checkout/edit',
  name: 'replace_entire_checkout_content_block',
  replace: "div#checkout_content",
  text: <<~ERB
    <div class="checkout-content mt-5" id="checkout_content">
      <% if @order.address? %>
        <%= render partial: 'spree/checkout/address', locals: { order: @order } %>
      <% elsif @order.payment? %>
        <%= render partial: 'spree/checkout/payment', locals: { order: @order } %>
      <% elsif @order.confirm? %>
        <%= render partial: 'spree/checkout/confirm', locals: { order: @order } %>
      <% elsif @order.delivery? %>
        <%= render partial: 'spree/checkout/delivery', locals: { order: @order } %>
      <% else %>
        <%= form_for @order, url: spree.update_checkout_path(@order.token, @order.state), html: { id: "checkout_form_\#{@order.state}" } do |form| %>
          <div>
            <%= form.hidden_field :state_lock_version unless @order.errors.any? %>
            <%= render @order.state, form: form %>
          </div>
          <div>
            <%= button_tag Spree.t(:save_and_continue),
                          class: 'btn btn-primary font-weight-bold w-full lg:w-48 float-right checkout-content-save-continue-button',
                          data: { 'turbo-submits-with': (render 'button_processing', is_hidden: false) } %>
          </div>
        <% end %>
      <% end %>
    </div>
  ERB
)
