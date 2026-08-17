module Spree
  module Admin
    module ProductsControllerDecorator
      private

      # @gem-override spree_admin-5.3.6/app/controllers/spree/admin/products_controller.rb#assign_master_images
      # @see https://github.com/be-agile/giga-repeat/issues/1292
      #
      # 新規商品の作成時、先にアップロードされた画像は viewable_id が nil のまま
      # 採番される。この採番スコープ (viewable_id: nil) は作成中の全商品で共有される
      # ため、master へ付け替えた直後の position は 1..N の連番にならない。
      # 本家は update_all で付け替えるだけで acts_as_list を通らないので、ここで詰め直す。
      def assign_master_images
        super

        Spree::Assets::PositionNormalizer.call(
          viewable_type: 'Spree::Variant',
          viewable_id: @product.master&.id
        )
      end
    end
  end
end

Spree::Admin::ProductsController.prepend(Spree::Admin::ProductsControllerDecorator)
