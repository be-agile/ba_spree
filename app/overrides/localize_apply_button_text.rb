Deface::Override.new(
  virtual_path: "spree/checkout/_coupon_code",
  name: "localize_apply_button_text",
  replace: "erb[loud]:contains('button_tag Spree.t(:apply)')",
  text: "<%= button_tag Spree.t(:apply), class: 'ml-3 btn-primary !px-4 !py-3 text-sm whitespace-nowrap', data: { 'enable-button-target': 'button' }, disabled: true %>"
)
