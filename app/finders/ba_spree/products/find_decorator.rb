module BaSpree
  module Products
    module FindDecorator
      private

      # @gem-override spree_core-5.3.6/app/finders/spree/products/find.rb#ordered
      # reason: 「関連性」の並び順で、親カテゴリの一覧に子カテゴリの商品が混ざって並ばないよう、
      #   カテゴリツリーの縦型探索順に並べる。
      # @see https://github.com/be-agile/giga-repeat/issues/1503
      def ordered(products)
        return super unless %w[default manual].include?(sort_by) && taxons?

        products.ascend_by_taxons_tree_position(taxons)
      end
    end
  end
end

Spree::Products::Find.prepend(BaSpree::Products::FindDecorator)
