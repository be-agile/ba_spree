# encoding: UTF-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ba_spree/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'ba_spree'
  s.version     = BaSpree::VERSION
  s.summary     = 'Be Agile Spree wrapper extension'
  s.description = 'This extension serves as a wrapper for all the Spree extensions used in the project'
  s.required_ruby_version = '>= 3.1.4'

  s.author      = 'be agile Co., Ltd.'
  s.email       = 'develop@be-agile.jp'
  s.homepage    = 'https://github.com/be-agile/ba_spree'
  s.licenses    = ['AGPL-3.0-or-later']

  # config/ には locale・initializer 4本・importmap.rb が入っており、
  # 含めないと gem として配布したときに JS と日本語が読まれない。
  # LICENSE / README.md も同梱しないと、gem を入れた人が
  # ライセンスを確認できない
  s.files       = Dir['{app,config,db,lib}/**/*', 'LICENSE', 'README*.md']
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree', '= 5.3.6'
  s.add_dependency 'spree_admin', '= 5.3.6'
  s.add_dependency 'spree_storefront', '= 5.3.6'
  # spree_i18n は本体(spree)と別リポジトリ・別バージョニングで、5.3.6 は存在しない
  # (最新は 5.3.2)。本体追従の影響を受けないよう範囲指定にする。
  s.add_dependency 'spree_i18n', '~> 5.3'
  s.add_dependency 'spree_emails', '= 5.3.6'

  # ba_spree は 29 ファイルで Deface::Override を使うが、spree_core 5.3.6 は
  # deface に依存していないため明示的に宣言する
  s.add_dependency 'deface'

  # 「日本人向けの EC サイトがすぐに作れる」を成立させるためのバンドル。
  # 日本の EC 商習慣(決済・住所・メール)、汎用の機能拡張、計測の engine をまとめて入れる
  # meta-gem (rails / spree と同じパターン)。
  # @see https://github.com/be-agile/giga-repeat/issues/1317
  #
  # lib/ba_spree.rb がここに書いた engine をすべて require する。一覧はこの gemspec だけに持つ。
  # engine とみなすのは homepage が https://github.com/be-agile/ の gem だけなので、新しい engine もそうすること。
  # @see https://github.com/be-agile/giga-repeat/issues/1403
  #
  # ba_spree より先にロードする engine (lib/ba_spree.rb で ba_spree/engine より前に明示的に require する)。
  # @see https://github.com/be-agile/giga-repeat/issues/1307
  s.add_dependency 'ba_spree_loyalty_points'
  s.add_dependency 'spree_materials'
  # Spree::BaseHelper#sort_adjustments_with_flat_percent_last が
  # Spree::Calculator::FlatPercentOrderTotal を参照する
  s.add_dependency 'spree_order_total_discount'
  # ba_spree より後にロードする engine。lib/ba_spree.rb がこの記載順で require するので、
  # 記載順 = engine のロード順 = decorator の prepend 順(下ほど外側)になる。
  # 並べ替えると giga-repeat 本番の decorator の重なり順も変わる
  s.add_dependency 'ba_spree_google_analytics'
  s.add_dependency 'spree_yahoo_ads'
  s.add_dependency 'spree_products_payment_methods'
  s.add_dependency 'ba_spree_cash_on_delivery'
  s.add_dependency 'ba_spree_related_products'
  s.add_dependency 'spree_np_atobarai'
  s.add_dependency 'spree_direct_debit'
  s.add_dependency 'spree_zip_autocomplete'
  s.add_dependency 'spree_address_format_i18n'
  s.add_dependency 'spree_custom_email'
  s.add_dependency 'ba_spree_bank_transfer'
  s.add_dependency 'spree_limit_order_quantity'
  s.add_dependency 'spree_option_type_description'
  s.add_dependency 'spree_search_with_description'
  s.add_dependency 'spree_auto_capture_digital'
  s.add_dependency 'spree_digital_payment_notice'
  s.add_dependency 'spree_checkout_signup_promotion'
  s.add_dependency 'spree_gmo_pg'

  # 配送カテゴリが違っても共通の配送方法があれば同梱する splitter。全 DeploymentUnit に入れる
  s.add_dependency 'spree_common_shipping_method_splitter'

  s.add_development_dependency 'gem_override_marker'
end
