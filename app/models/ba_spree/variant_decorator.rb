module BaSpree
  module VariantDecorator
    # @gem-override spree_core-5.3.6/app/models/spree/variant.rb#set_option_value
    # @see https://github.com/be-agile/giga-repeat/commit/108316dd2cab88a61933080614e15663517c7291
    def set_option_value(opt_name, opt_value, opt_type_position = nil)
      # no option values on master
      return if is_master

      option_type = Spree::OptionType.where(name: opt_name).first_or_initialize do |o|
        o.name = o.presentation = opt_name
        o.save!
      end

      current_value = find_option_value(opt_name)

      if current_value.nil?
        # then we have to check to make sure that the product has the option type
        product_option_type = if (existing_prod_ot = product.product_option_types.find { |ot| ot.option_type_id == option_type.id })
          existing_prod_ot
        else
          product_option_type = product.product_option_types.new
          product_option_type.option_type = option_type
        end
        product_option_type.position = opt_type_position if opt_type_position
        product_option_type.save! if product_option_type.new_record? || product_option_type.changed?
      else
        return if current_value.name == opt_value

        option_values.delete(current_value)
      end

      option_value = option_type.option_values.where(name: opt_value).first_or_initialize do |o|
        o.name = o.presentation = opt_value
        o.save!
      end

      option_values << option_value
      save
    end

    # @gem-override spree_core-5.3.6/app/models/spree/variant.rb#find_option_value
    # @see https://github.com/be-agile/giga-repeat/commit/108316dd2cab88a61933080614e15663517c7291
    def find_option_value(opt_name)
      option_values.includes(:option_type).detect { |o| o.option_type.name == opt_name }
    end
  end
end

Spree::Variant.prepend(BaSpree::VariantDecorator)
