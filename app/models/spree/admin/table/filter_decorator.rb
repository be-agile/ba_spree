module Spree
  module Admin
    class Table
      # 本家 Spree::Admin::Table::Filter の OPERATORS は label が英語ハードコード
      # ("equals" 等)で、フィルタービルダーの演算子セレクトが日本語にならない
      # 原因の一つ(Ruby 側)。operators_for_select はこの label を
      # data-query-builder-operators-value として JS に渡すため、ここを i18n
      # (admin.tables.operators.*) から引くよう上書きする。
      #
      # 注意: OPERATORS 定数を起動時に書き換えるとロケールが起動時で固定されて
      # しまうため、リクエストごとに評価される operators_for_select 側で翻訳する。
      module FilterDecorator
        module ClassMethods
          # OPERATORS の各 operator キー -> i18n キー(admin.tables.operators 配下)。
          # キーと i18n キーの対応は本家ビュー(_filter_row 等)が使う
          # admin.tables.operators.* に合わせる。
          OPERATOR_I18N_KEYS = {
            eq: :equals,
            not_eq: :not_equals,
            cont: :contains,
            not_cont: :does_not_contain,
            start: :starts_with,
            end: :ends_with,
            gt: :greater_than,
            gteq: :greater_than_or_equal,
            lt: :less_than,
            lteq: :less_than_or_equal,
            in: :is_any_of,
            not_in: :is_none_of,
            null: :is_empty,
            not_null: :is_not_empty
          }.freeze

          def operators_for_select
            super.map do |operator|
              i18n_key = OPERATOR_I18N_KEYS[operator[:value].to_sym]
              next operator unless i18n_key

              operator.merge(label: Spree.t("admin.tables.operators.#{i18n_key}"))
            end
          end
        end

        def self.prepended(base)
          base.singleton_class.prepend(ClassMethods)
        end
      end
    end
  end
end

Spree::Admin::Table::Filter.prepend(Spree::Admin::Table::FilterDecorator)
