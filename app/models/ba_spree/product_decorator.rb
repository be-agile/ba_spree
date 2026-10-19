module BaSpree
  module ProductDecorator
    def self.prepended(base)
      # Spree 5.3 以前は、商品ごとのオプション並び順(spree_product_option_types.position)を正にするため
      # `option_types` を reorder('spree_product_option_types.position') で上書きしていた。
      # しかし through association の order/reorder に「他テーブルの列」を書くと、Rails が preload
      # (WHERE id IN (...)) で読む経路で JOIN が外れ ORDER 句だけ残るため、
      # 「Unknown column 'spree_product_option_types.position' in 'order clause'」で
      # taxons#show(カテゴリページ)が 500 になる(5.3 で option_types を preload する経路が増え顕在化)。
      #
      # この罠は through の order に他テーブル列を書く限り原理的に回避できないため、上書きを削除し
      # 5.3 core のデフォルト(`option_types, through: :product_option_types` + `product_option_types
      # -> order(:position)`)に委ねる。これにより並び順は
      # `spree_option_types.position`(グローバル順) → `spree_product_option_types.position`(商品ごと順)
      # の複合になり、「商品ごと順」は第2ソートキーへ後退する。
      # ※ org4 の複数 option_type 商品 355 件すべてで両者の並び順が一致することを確認済み(実害なし)。
      #   将来「商品ごとにオプション表示順を変える」運用が必要になった場合は、option_types を直接
      #   並べ替えるのではなく product_option_types.order(:position) 経由で option_type を引く形に
      #   変更すること(preload 安全な書き方が必要)。
      base.has_many :option_types_for_includes, -> { order(:id) },
                    through: :product_option_types,
                    source: :option_type,
                    class_name: 'Spree::OptionType'

      # ProductProperty -> metafields 移行用の読み書きヘルパー(Spree 5.4 の Property 削除対応)
      base.include Spree::ProductPropertyMetafields

      # 指定カテゴリ群の中で、カテゴリツリーを縦型探索した順(lft) → カテゴリ内の商品の並び順(position) に並べる。
      # 複数のカテゴリに属する商品は、最初に出てくる位置で並ぶ。
      # taxon は、絞り込みに使う spree_products_taxons の行からたどり、指定カテゴリ群の行だけで MIN をとる。
      base.add_search_scope :ascend_by_taxons_tree_position do |taxon_ids|
        # position(INT)の上の桁に lft を置いた1つの整数にする
        tree_position_sql = "MIN(#{Spree::Taxon.table_name}.lft * #{2**32} + #{Spree::Classification.table_name}.position)"

        joins(classifications: :taxon).
          where(Spree::Classification.table_name => { taxon_id: taxon_ids }).
          select("#{Spree::Product.table_name}.*", "#{tree_position_sql} AS taxon_tree_position").
          group("#{Spree::Product.table_name}.id").
          order(Arel.sql("#{tree_position_sql} ASC"))
      end
    end

    def set_slug
      self.slug = generate_slug
    end

    private
    def generate_slug
      if new_record?
        uuid_for_friendly_id
      else
        self.changes["slug"]&.first || self.slug
      end
    end
  end
end

Spree::Product.prepend(BaSpree::ProductDecorator)
