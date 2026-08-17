module Spree
  # @gem-override spree_core-5.3.6/app/models/spree/current.rb
  # reason: 価格表(price_list)を一覧・関連商品・セールラベルで「ログイン中ユーザのグループ」に
  #   正しく反映させるため、リクエストスコープの pricing_user を保持できるようにする。
  #   本家の Spree::Current には user 属性が無く、Product#lowest_price 等が pricing context を
  #   通らないため、ゲストや対象外ユーザにも他グループの最安値・セールラベルが漏れていた (Issue #1219)。
  # @see https://github.com/be-agile/giga-repeat/issues/1219
  module CurrentDecorator
    extend ActiveSupport::Concern

    included do
      attribute :pricing_user
    end
  end
end

Spree::Current.include(Spree::CurrentDecorator)
