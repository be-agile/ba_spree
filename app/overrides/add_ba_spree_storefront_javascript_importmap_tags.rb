Deface::Override.new(
  virtual_path: 'spree/shared/_head',
  name: 'add_ba_spree_storefront_javascript_importmap_tags',
  insert_after: "erb[loud]:contains('javascript_importmap_tags')",
  text: <<-ERB
    <%= javascript_import_module_tag 'ba_spree' %>
  ERB
)
