module Spree
  module PriceRules
    module VolumeRuleDecorator
      module ClassMethods
        # @gem-override spree_core-5.3.6/app/models/spree/price_rule.rb#human_name
        # Spree 5.3: 本家 self.human_name は name.demodulize.titleize で英語固定(i18n を引かない)。
        # 価格表ルール追加モーダルの見出しを日本語化するため i18n を引く。
        # 訳語は config/locales/spree.ja.yml の spree.price_rules.volume_rule.name。
        def human_name
          Spree.t('price_rules.volume_rule.name')
        end

        # @gem-override spree_core-5.3.6/app/models/spree/price_rules/volume_rule.rb#description
        # Spree 5.3: 本家 self.description は英語文字列をハードコードしており i18n を引かない。
        # CustomerGroupRule のみ Spree.t を使うため、VolumeRule も同流儀で i18n 化し日本語化する。
        # 訳語は config/locales/spree.ja.yml の spree.price_rules.volume_rule.description。
        def description
          Spree.t('price_rules.volume_rule.description')
        end
      end
    end
  end
end

Spree::PriceRules::VolumeRule.singleton_class.prepend(Spree::PriceRules::VolumeRuleDecorator::ClassMethods)
