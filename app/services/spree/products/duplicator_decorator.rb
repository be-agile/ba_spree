module Spree
  module Products
    # 商品複製時の variant_count カウンタキャッシュずれを補正する。
    #
    # 背景:
    #   Spree 5.3.6 で `spree_products.variant_count` カウンタキャッシュが導入され、
    #   `Spree::Product#has_variants?` はこの値を参照するようになった。
    #   しかし upstream の Duplicator は `product.dup` で元商品の variant_count を
    #   そのまま引き継いだ上、複製したバリエーションを autosave するため
    #   `Spree::Variant#increment_product_variant_count` が二重に走り、
    #   複製先の variant_count が「元の件数 + 複製件数」に膨らむ。
    #
    #   その状態で複製先のバリエーションを全削除すると、
    #   削除1件につき1ずつしか減らないため variant_count が 0 にならず、
    #   バリエーションが無いのに has_variants? が true のままとなり、
    #   バリエーションなし商品としての在庫(数量)設定フォームが表示されなくなる。
    #
    # 対策:
    #   複製・保存後の新商品について、実際の非マスターバリエーション件数で
    #   variant_count を上書きし、dup 引き継ぎ + autosave 二重カウントを打ち消す。
    #
    # @see https://github.com/be-agile/giga-repeat/issues/1250
    module DuplicatorDecorator
      # @gem-override spree_core-5.3.6/app/services/spree/products/duplicator.rb#call
      # @see https://github.com/be-agile/giga-repeat/issues/1250
      def call(product:, include_images: true)
        super.tap do |result|
          new_product = result.value
          next unless new_product.is_a?(Spree::Product) && new_product.persisted?

          actual_count = new_product.variants.reload.count
          new_product.update_column(:variant_count, actual_count)
        end
      end
    end
  end
end

Spree::Products::Duplicator.prepend(Spree::Products::DuplicatorDecorator)
