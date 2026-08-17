Deface::Override.new(
  virtual_path: "spree/admin/stores/form/_basic",
  name: "set_logo_width_height_in_admin_store_basic_form",
  replace: "erb[loud]:contains('f.spree_file_field :logo')",
  text: <<~ERB
    <% logo = f.object.logo %>
    <% logo.analyze if logo.present? && !logo.analyzed? %>
    <% width = logo.metadata&.dig('width') || 240  %>
    <% height = logo.metadata&.dig('height') || 240 %>
    <%= f.spree_file_field :logo, width: width, height: height, crop: true, help_bubble: Spree.t('admin.store.logo_help') %>
  ERB
)
