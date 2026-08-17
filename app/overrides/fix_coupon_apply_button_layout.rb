# Fix coupon code apply button layout to prevent text wrapping
Deface::Override.new(
  virtual_path: 'spree/checkout/_coupon_code',
  name: 'fix_coupon_apply_button_layout',
  replace: 'erb[loud]:contains("button_tag Spree.t(:apply)"):contains("btn-primary")',
  text: '<%= button_tag Spree.t(:apply), class: "ml-3 btn-primary !px-3 !py-2 text-sm whitespace-nowrap", data: { "enable-button-target": "button" }, disabled: true %>'
)
