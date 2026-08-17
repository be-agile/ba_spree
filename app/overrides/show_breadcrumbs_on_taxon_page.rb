# カテゴリ(Taxon)ページの Breadcrumbs セクションにパンくずを表示する。
# upstream のセクション用パーシャルは @product があるときしか描画しないため、
# @taxon があるカテゴリページでは何も表示されなかった。
# nav#breadcrumbs の内側末尾に @taxon 分岐を追加し、祖先→現在カテゴリのパンくずを描画する。
# @product 側の既存出力には手を入れないため、商品詳細ページへの影響はない。
# See: https://github.com/be-agile/giga-repeat/issues/1256
Deface::Override.new(
  virtual_path: "spree/page_sections/_breadcrumbs",
  name: "show_breadcrumbs_on_taxon_page",
  insert_bottom: "nav#breadcrumbs",
  text: <<~ERB
    <% if @product.blank? && @taxon.present? %>
      <% taxons = @taxon.self_and_ancestors.includes(:translations).find_all { |taxon| taxon.depth != 0 } %>

      <ul class="inline-flex gap-3 text-sm">
        <% taxons.each_with_index do |taxon, index| %>
          <% is_current = taxon == @taxon %>
          <li class="<%= is_current ? 'text-text opacity-100 font-medium' : 'opacity-50' %>">
            <% if is_current %>
              <%= taxon.name %>
            <% else %>
              <%= link_to taxon.name, spree.nested_taxons_path(taxon), title: taxon.name %>
            <% end %>
          </li>
          <div class="breadcrumb-square opacity-50 <%= 'hidden' if index == taxons.length - 1 %>"></div>
        <% end %>
      </ul>
    <% end %>
  ERB
)
