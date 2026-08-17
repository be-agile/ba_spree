module Spree
  module MegaNavPresenterDecorator
    ColumnPresenter = Struct.new(:title, :links, :view_all_linkable, keyword_init: true)

    # @gem-override spree_storefront-5.3.6/app/presenters/spree/mega_nav_presenter.rb#columns
    # @see https://github.com/be-agile/giga-repeat/commit/3d8f8c44f9a0d119fb24f9b8b19001fd7be20c2c
    def columns
      @columns ||=
        if mega_nav.is_a?(Spree::PageBlocks::MegaNavWithSubcategories)
          grouped_by_parent = mega_nav.taxon&.self_and_descendants&.group_by(&:parent_id) || []
          main_subcategories = grouped_by_parent[mega_nav.taxon.id].to_a.sort_by(&:position)

          main_subcategories.first(max_columns).map do |child_category|
            links = grouped_by_parent[child_category.id].to_a.sort_by(&:position).map(&method(:to_link))
            ColumnPresenter.new(title: child_category.name, links: links, view_all_linkable: child_category)
          end.compact_blank
        elsif mega_nav.is_a?(Spree::PageBlocks::MegaNav)
          [ ColumnPresenter.new(title: main_link.label, links: mega_nav.links.drop(1), view_all_linkable: main_link.linkable) ]
        else
          []
        end
    end
  end
end

Spree::MegaNavPresenter.prepend Spree::MegaNavPresenterDecorator
