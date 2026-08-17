Deface::Override.new(
  virtual_path: "spree/checkout/_delivery",
  name: "replace_delivery_method_header_content",
  replace_contents: "h5.checkout-content-header",
  text: "<strong><%= Spree.t('storefront.checkout.delivery_method').capitalize %></strong>"
)
