# app/decorators/controllers/spree/admin/promotion_rules_controller_decorator.rb
module Spree
  module Admin
    module PromotionRulesControllerDecorator
      def option_values_search
        search_term = params[:q]
        option_values = if search_term.present?
          Spree::OptionValue.joins(:option_type)
            .where("LOWER(spree_option_values.name) LIKE ? OR LOWER(spree_option_values.presentation) LIKE ?",
                  "%#{search_term.downcase}%", "%#{search_term.downcase}%")
            .distinct
        else
          Spree::OptionValue.limit(30)
        end

        # Format option values for tom_select
        result = option_values.map do |option_value|
          {
            id: option_value.id,
            name: "#{option_value.option_type_presentation}: #{option_value.presentation}"
          }
        end

        render json: result
      end
    end
  end
end

Spree::Admin::PromotionRulesController.prepend(Spree::Admin::PromotionRulesControllerDecorator)
