require 'spree_core'
require 'spree_admin'
require 'spree_storefront'
require 'spree_i18n'
require 'spree_emails'
# gemspec で add_dependency している engine は、ここでも require してロード順を固定する。
# ba_spree_loyalty_points は Spree::Order / Spree::Store / Spree::PaymentMethod /
# Spree::CheckoutController を ba_spree と同じく decorate しており、どちらの decorator が外側に
# prepend されるかが Gemfile の記載順で決まってしまう。依存先を先にロードすることで、土台である
# 依存先の上に ba_spree が重なる形（ba_spree が外側）に固定する。
# spree_materials は現時点では ba_spree 側からのコード参照がないが、同じ理由で順序を固定しておく。
# @see https://github.com/be-agile/giga-repeat/issues/1307
require 'ba_spree_loyalty_points'
require 'spree_materials'
# Spree::BaseHelperDecorator#sort_adjustments_with_flat_percent_last が
# Spree::Calculator::FlatPercentOrderTotal を参照する。
# @see https://github.com/be-agile/giga-repeat/issues/1307
require 'spree_order_total_discount'
require 'ba_spree/engine'
require 'ba_spree/version'
