Deface::Override.new(
  virtual_path: 'spree/shared/_cart_pane',
  name: 'add_turbo_stream_format_to_cart_path_in_cart_pane',
  replace: "erb[loud]:contains('turbo_frame_tag cart_id(order)')",
  text: <<-ERB
    <%= turbo_frame_tag cart_id(order), class: 'cart-contents', src: spree.cart_path(format: :turbo_stream), loading: :lazy %>
  ERB
)
