module Spree
  module PriceRules
    module CustomerGroupRuleDecorator
      module ClassMethods
        # @gem-override spree_core-5.3.6/app/models/spree/price_rule.rb#human_name
        # Spree 5.3: 本家 self.human_name は name.demodulize.titleize で英語固定(i18n を引かない)。
        # 価格表ルール追加モーダルの見出しを日本語化するため i18n を引く。
        # (description は本家 CustomerGroupRule が既に Spree.t を使い日本語化済みのため上書き不要)
        # 訳語は config/locales/spree.ja.yml の spree.price_rules.customer_group_rule.name。
        def human_name
          Spree.t('price_rules.customer_group_rule.name')
        end
      end
    end
  end
end

Spree::PriceRules::CustomerGroupRule.singleton_class.prepend(Spree::PriceRules::CustomerGroupRuleDecorator::ClassMethods)
