module Spree
  module BaseHelperDecorator
    CHILD_TAXONS_SECTION_DEFAULT_PREFERENCES = {
      heading_size: 'medium',
      heading_alignment: 'center'
    }.freeze

    # 子カテゴリを「注目カテゴリ」セクションとして描画する。
    # taxon ページの商品グリッド (_product_grid.html.erb) から呼ばれる。
    def render_child_taxons_section(taxon, preferences: CHILD_TAXONS_SECTION_DEFAULT_PREFERENCES)
      return if taxon.blank?

      children = taxon.children
      return if children.blank?

      section = Spree::PageSections::FeaturedTaxons.build
      (preferences || {}).each do |key, value|
        section.send("preferred_#{key}=", value)
      end

      section.links = children.map do |child|
        Spree::PageLink.build(label: child.name, linkable: child)
      end

      render('spree/page_sections/featured_taxons', section: ChildTaxonsSection.new(section))
    end

    # 永続化されていない PageSection をラップし、フラグメントキャッシュのキーを
    # 子カテゴリの内容から導出する。
    # 未保存の AR レコードは cache_key が常に ".../new" になり、カテゴリを跨いで
    # キャッシュが衝突するため。
    class ChildTaxonsSection < SimpleDelegator
      def cache_key
        child_taxon_ids = links.map(&:linkable_id)
        max_updated_at = links.filter_map(&:linkable).map(&:updated_at).max.to_i
        "spree/page_sections/child_taxons/#{child_taxon_ids.join('-')}-#{max_updated_at}"
      end

      # ActiveSupport::Cache は cache_key より先にこちらを見るため、
      # 委譲先の実装が使われないよう合わせて上書きする
      def cache_key_with_version
        cache_key
      end
    end

    def sort_adjustments_with_flat_percent_last(adjustments)
      adjustments.sort_by do |adj|
        if adj.adjustable_type == 'Spree::Order' && adj.source_type == 'Spree::PaymentMethod'
          3
        elsif adj.source_type == 'Spree::PromotionAction' &&
            adj.source&.calculator&.is_a?(Spree::Calculator::FlatPercentOrderTotal)
          2
        elsif adj.source_type == 'Spree::PromotionAction'
          1
        else
          0
        end
      end
    end
  end
end

Spree::BaseHelper.prepend Spree::BaseHelperDecorator
