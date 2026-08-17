module Spree
  module Admin
    module PromotionRulesHelperDecorator
      # オプション値プロモーションルールのアクティブなオプションを取得するメソッドをオーバーライド
      # @gem-override spree_admin-5.3.6/app/helpers/spree/admin/promotion_rules_helper.rb#active_options_for_option_value_promotion_rule
      # reason: 実装当時は本家未実装だったため独自実装した。その後 spree_admin 5.1.6 で本家にも
      #   同名メソッドが追加され、現在は本家実装を super なしで上書きしている状態 (commit a8034366)
      # @see https://github.com/be-agile/giga-repeat/commit/a803436627949044869c3dfdae26f8909ecaf617
      def active_options_for_option_value_promotion_rule(promotion_rule)
        eligible_values = promotion_rule.preferred_eligible_values || []
        return [] if eligible_values.empty?

        # eligible_valuesはoption_value_idのリストなので、idではなくoption_value_idで検索
        option_values = Spree::OptionValue.joins(:option_type)
                                         .where(id: eligible_values)
                                         .select('spree_option_values.id,
                                                 spree_option_values.presentation AS value_presentation,
                                                 spree_option_types.presentation AS type_presentation')

        # tom-select用のJSON形式にフォーマット
        option_values.map do |ov|
          {
            id: ov.id,
            name: "#{ov.type_presentation}: #{ov.value_presentation}"
          }
        end
      end
    end
  end
end

# Decoratorを適用
Spree::Admin::PromotionRulesHelper.prepend(Spree::Admin::PromotionRulesHelperDecorator)
