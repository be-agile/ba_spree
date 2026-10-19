module Spree
  module BaseHelperDecorator
    # Issue #1153: ストアフロントのフラグメントキャッシュのキーは、本家では
    #   locale / currency / ログイン中か否か / role_users しか持たず、ユーザごとの差が入らない。
    #   このままカテゴリ・商品・価格をユーザごとに絞ると、別のユーザ向けに生成された HTML が
    #   そのまま出るため、顧客グループID(ソート済み)を署名として足して分離する。
    #   spree_storefront_base_cache_key の中身でもあるため、ナビ・一覧・絞り込みサイドバーが
    #   これ1箇所で分離される。Issue #1219 で残っていた「一覧の価格が別グループのユーザに
    #   見える」経路の修正も兼ねる。
    # 本家と同じく defined?(try_spree_current_user) のガードを維持する
    #   (Spree::BaseHelper は Spree::MailHelper と Spree::VariantPresenter にも include され、
    #    そこでは try_spree_current_user が未定義のため)。
    # @see https://github.com/be-agile/giga-repeat/issues/1153
    # メモ化には本家と別の ivar を使う。本家も @spree_base_cache_key に ||= するため、同じ
    # ivar を使うと「||= が左辺を先に読む」という評価順序に依存することになり、本家の実装が
    # 変わったときに顧客グループIDだけが無音で落ちる(別グループ向けの HTML が出る)。
    def spree_base_cache_key
      @ba_spree_base_cache_key ||= [
        *super,
        (defined?(try_spree_current_user) && try_spree_current_user.try(:customer_group_ids)&.sort)
      ].compact
    end

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
        max_updated_at = links.map(&:linkable).map(&:updated_at).max.to_i
        "#{child_taxon_ids.join('-')}-#{max_updated_at}"
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
