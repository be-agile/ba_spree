module Spree
  module Adjustable
    module Adjuster
      module PromotionDecorator
        # @gem-override spree_core-5.3.6/app/models/spree/adjustable/adjuster/promotion.rb#choose_best_promo_adjustment
        # @see https://github.com/be-agile/giga-repeat/commit/3d5683b6c3e6875cfd808368f0ab21c020270ebb
        # 本家は競合プロモーション adjustment のうち最良のもの以外を eligible: false にするが、
        # ba_spree では複数プロモーションを併用させるため、この絞り込みを無効化する。
        def choose_best_promo_adjustment
        end
      end
    end
  end
end

Spree::Adjustable::Adjuster::Promotion.prepend(Spree::Adjustable::Adjuster::PromotionDecorator)
