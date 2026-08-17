Deface::Override.new(
  virtual_path: 'spree/admin/shared/sidebar/_store_nav',
  name: 'add_promotions_nav_to_store_nav',
  replace: "erb[loud]:contains(\"render 'spree/admin/shared/sidebar/promotions_nav'\")",
  text: <<-HTML
    <%= render 'spree/admin/shared/sidebar/promotions_nav' %>
  HTML
)
