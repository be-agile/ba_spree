Deface::Override.new(
  virtual_path: 'spree/shared/_head',
  name: 'ba_spree_loca_time_add_custom_javascript_importmap_tags',
  insert_after: "erb[loud]:contains('javascript_importmap_tags')",
  text: <<-ERB
    <%= javascript_import_module_tag 'ba-spree-local-time' %>
  ERB
)
