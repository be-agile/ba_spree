module Spree
  module Products
    module PrepareNestedAttributesDecorator
      # @gem-override spree_core-5.3.6/app/services/spree/products/prepare_nested_attributes.rb#update_option_value_variants
      # @see https://github.com/be-agile/giga-repeat/commit/108316dd2cab88a61933080614e15663517c7291
      def update_option_value_variants(option_value_params, existing_variant)
        return {} unless option_value_params.present?
        return {} unless can_manage_option_types?

        option_value_variant_params = {}

        option_value_params.each_with_index do |opt, index|
          option_type = Spree::OptionType.find_by(id: opt[:id]) if opt.fetch(:id)
          option_type ||= Spree::OptionType.where(name: opt[:name]).first_or_initialize do |o|
            o.name = o.presentation = opt[:name]
            o.position = opt[:position]
            o.save!
          end
          option_value_identificator = if opt[:option_value_name].present?
            opt[:option_value_name]
          else
            opt[:option_value_presentation]
          end.strip

          option_value = option_type.option_values.where(name: option_value_identificator).first_or_initialize do |o|
            o.presentation = opt[:option_value_presentation]
            o.save!
          end

          existing_option_value_variant = existing_variant&.option_value_variants&.find { |ovv| ovv.option_value_id == option_value.id }

          option_value_variant_params[index.to_s] = { id: existing_option_value_variant&.id, option_value_id: option_value.id }.compact_blank

          next if product_option_types_params.find { |_i, v| v[:option_type_id] == option_type.id }

          existing_product_option_type = @product.product_option_types.find { |pot| pot.option_type_id == option_type.id }

          if existing_product_option_type
            product_option_types_to_remove.delete(existing_product_option_type.id)
            product_option_types_params[opt[:position]] = {
              id: existing_product_option_type.id,
              position: opt[:position],
              option_type_id: option_type.id
            }
          else
            product_option_types_params[opt[:position]] = {
              option_type_id: option_type.id,
              position: opt[:position]
            }
          end
        end

        option_value_variant_params
      end
    end
  end
end
Spree::Products::PrepareNestedAttributes.prepend(Spree::Products::PrepareNestedAttributesDecorator)
