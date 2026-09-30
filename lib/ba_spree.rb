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
# @see https://github.com/be-agile/giga-repeat/issues/1400
require 'spree_common_shipping_method_splitter'
require 'ba_spree/engine'
require 'ba_spree/version'

module BaSpree
  # ba_spree が束ねる engine の gem 名(ba_spree.gemspec の記載順)。
  # 依存のうち be-agile org で公開している gem を engine とみなし、spree 本体や deface は除く。
  def self.bundled_engine_names
    Gem.loaded_specs.fetch('ba_spree').runtime_dependencies.map(&:name).select do |name|
      Gem.loaded_specs[name]&.homepage&.start_with?('https://github.com/be-agile/')
    end
  end
end

# ba_spree.gemspec が依存する engine を、gemspec の記載順ですべて require する(上で require 済みのものは何も起きない)。
# Bundler.require は Gemfile に書かれた gem しか require しないため、`gem "ba_spree"` だけを書いた利用者の環境では
# ここで require しないと engine として登録されない。ba_spree より後にロードするので decorator は ba_spree の外側に重なる。
# giga-repeat でも Gemfile.basic の先頭の ba_spree がここで全て require するため、本番の engine のロード順も
# gemspec の記載順で決まる。engine の一覧を gemspec だけに持ち、ここや Gemfile との二重管理を避ける。
# @see https://github.com/be-agile/giga-repeat/issues/1403
BaSpree.bundled_engine_names.each { |name| require name }
