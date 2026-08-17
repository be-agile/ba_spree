module Spree
  module OptionValueVariantDecorator
    def self.prepended(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # @gem-override spree_core-5.3.6/app/models/spree/base.rb#to_tom_select_json
      # @see https://github.com/be-agile/giga-repeat/commit/108316dd2cab88a61933080614e15663517c7291
      # カスタムto_tom_select_jsonメソッドの実装
      # OptionValueVariantにはnameがないため、関連するOptionValueとOptionTypeから情報を取得
      def to_tom_select_json
        joins(:option_value)
          .joins('JOIN spree_option_types ON spree_option_types.id = spree_option_values.option_type_id')
          .select('spree_option_value_variants.id,
                  spree_option_values.presentation AS value_presentation,
                  spree_option_types.presentation AS type_presentation')
          .map do |ov|
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
Spree::OptionValueVariant.prepend(Spree::OptionValueVariantDecorator)
