module Spree
  module PromotionHandler
    module CartDecorator
      private

      # @gem-override spree_core-5.3.6/app/models/spree/promotion_handler/cart.rb#promotions
      # @see https://github.com/be-agile/giga-repeat/issues/723
      # プロモーションが大量にあるとカート処理が重くなるため、本家のスコープ取得を
      # UNION の生 SQL に置き換え、カート内容にマッチしない Product ルールを除外する。
      def promotions
        union_sql = "#{order.promotions.active.to_sql} UNION #{promotion_scope.active.automatic.to_sql}"

        if exclude_promotion_ids.present?
          final_sql = "SELECT * FROM (#{union_sql}) AS unioned_promotions WHERE id NOT IN (#{exclude_promotion_ids.join(',')})"
          promotion_scope.find_by_sql(final_sql)
        else
          promotion_scope.find_by_sql(union_sql)
        end
      end

      def exclude_promotion_ids
        cart_product_ids = order.line_items.joins(:variant).pluck('spree_variants.product_id').uniq
        # Find all promotions with Product rules
        all_product_rule_promotions = Spree::Promotion
          .joins(:promotion_rules)
          .where(promotion_rules: { type: 'Spree::Promotion::Rules::Product' })
          .distinct

        return all_product_rule_promotions.pluck(:id) if cart_product_ids.blank?

        # Find promotions with Product rules that match cart contents
        # Use ProductPromotionRule as starting point since the association exists
        matching_promotion_rule_ids = Spree::ProductPromotionRule
          .where(product_id: cart_product_ids)
          .joins(:promotion_rule)
          .where(promotion_rule: { type: 'Spree::Promotion::Rules::Product' })
          .pluck(:promotion_rule_id)

        matching_promotions = Spree::Promotion
          .joins(:promotion_rules)
          .where(promotion_rules: { id: matching_promotion_rule_ids })
          .distinct

        # Exclude Product rule promotions that don't match cart contents
        all_product_rule_promotions.where.not(id: matching_promotions.select(:id)).pluck(:id)
      end
    end
  end
end

Spree::PromotionHandler::Cart.prepend(Spree::PromotionHandler::CartDecorator)
