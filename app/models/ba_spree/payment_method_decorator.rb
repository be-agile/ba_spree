module BaSpree
  module PaymentMethodDecorator
    def tax_category
      return nil unless respond_to?(:preferred_tax_category_id)
      Spree::TaxCategory.find_by(id: preferred_tax_category_id) if preferred_tax_category_id.present?
    end
  end
end

Spree::PaymentMethod.prepend(BaSpree::PaymentMethodDecorator)
