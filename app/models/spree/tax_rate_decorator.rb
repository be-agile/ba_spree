module Spree
  module TaxRateDecorator
    def adjust_order_level_adjustments(order)
      return unless order.tax_address.nil? || zone.include?(order.tax_address)

      order_adjustments = order.adjustments.eligible.non_tax
                              .where(adjustable_type: 'Spree::Order')

      total_tax_amount = 0

      order_adjustments.each do |adjustment|
        tax_amount = calculate_tax_for_adjustment(adjustment)
        total_tax_amount += tax_amount if tax_amount
      end

      return if total_tax_amount.round(0).zero?

      existing_tax = find_existing_tax_adjustment_for_order(order)

      if existing_tax
        update_tax_adjustment(existing_tax, total_tax_amount)
      else
        create_tax_adjustment(order, total_tax_amount)
      end
    end

    def calculate_tax_for_adjustment(adjustment)
      tax_category = get_tax_category_for_adjustment(adjustment)
      return nil unless tax_category
      return nil unless tax_category == self.tax_category
      return nil if adjustment.amount.zero?

      pre_tax_amount = adjustment.amount / (1 + amount)
      tax_amount = adjustment.amount - pre_tax_amount

      tax_amount
    end

    def get_tax_category_for_adjustment(adjustment)
      source = adjustment.source
      return nil unless source

      case adjustment.source_type
      when 'Spree::PromotionAction'
        # 定額(FlatRate)など tax_category を持たない calculator もあるため、
        # respond_to? でガードして NoMethodError を避ける(try で同等)。
        source.calculator.try(:tax_category)
      when 'Spree::Calculator'
        source.try(:tax_category)
      when 'Spree::ShippingMethod'
        source.try(:tax_category)
      when 'Spree::PaymentMethod'
        source.try(:tax_category)
      else
        nil
      end
    end

    def find_existing_tax_adjustment_for_order(order)
      order.adjustments.tax.find_by(
        source_type: 'Spree::TaxRate',
        source_id: id,
        adjustable_type: 'Spree::Order'
      )
    end

    def create_tax_adjustment(order, tax_amount)
      order.adjustments.create!(
        adjustable_type: 'Spree::Order',
        adjustable_id: order.id,
        amount: tax_amount.round(0),
        included: true,
        label: label,
        order: order,
        state: 'closed',
        source_type: 'Spree::TaxRate',
        source_id: id
      )
    end

    def update_tax_adjustment(existing_tax, tax_amount)
      new_amount = tax_amount.round(0)
      if existing_tax.amount != new_amount
        existing_tax.update_columns(
          amount: new_amount,
          updated_at: Time.current
        )
      end
    end
  end
end

Spree::TaxRate.prepend(Spree::TaxRateDecorator)
