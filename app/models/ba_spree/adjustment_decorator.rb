module BaSpree
  module AdjustmentDecorator
    def self.prepended(base)
      base.scope :payment_method, -> { where(source_type: 'Spree::PaymentMethod') }
      base.scope :non_payment_method, -> { where.not(source_type: 'Spree::PaymentMethod') }
      base.scope :non_shipping, -> { where.not(adjustable_type: 'Spree::Shipment') }
      base.scope :promotion, -> { where(source_type: 'Spree::PromotionAction') }
      base.scope :non_promotion, -> { where.not(source_type: 'Spree::PromotionAction') }
    end
  end
end

Spree::Adjustment.prepend BaSpree::AdjustmentDecorator
