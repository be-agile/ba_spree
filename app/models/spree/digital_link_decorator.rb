module Spree
  module DigitalLinkDecorator
    def downloadable?
      line_item.order.paid?
    end
  end
end

Spree::DigitalLink.prepend Spree::DigitalLinkDecorator
