# frozen_string_literal: true

# Add fragment cache to product listing page to improve performance
# This prevents the expensive product query and filter UI from being executed on every request

# Cache for product_grid render (turbo_frame_request path)
Deface::Override.new(
  virtual_path: 'spree/shared/_product_listing_page',
  name: 'add_cache_to_product_grid_render',
  surround: "erb[loud]:contains('product_grid')",
  text: <<~ERB
    <% cache spree_base_cache_scope.call([
         @taxon,           # Auto-invalidate when product/property/child category changes
         current_page.sections.find_by(type: 'Spree::PageSections::ProductGrid'),  # Section settings
         params[:page],    # Pagination support
         params[:sort_by], # Sorting support
         params[:filter],  # Filter support (price, categories, options)
         'product-grid'
       ].compact) do %>
      <%= render_original %>
    <% end %>
  ERB
)

# Cache for render_page (normal page render path)
Deface::Override.new(
  virtual_path: 'spree/shared/_product_listing_page',
  name: 'add_cache_to_render_page',
  surround: "erb[loud]:contains('render_page')",
  text: <<~ERB
    <% cache spree_base_cache_scope.call([
         @taxon,           # Auto-invalidate when product/property/child category changes
         params[:page],    # Pagination support
         params[:sort_by], # Sorting support
         params[:filter],  # Filter support (price, categories, options)
         'render-page'
       ].compact) do %>
      <%= render_original %>
    <% end %>
  ERB
)
