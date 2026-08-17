# frozen_string_literal: true

module Spree
  module Admin
    class Table
      # フィルタービルダーの「または」グループが ransack に届かず、絞り込みとして機能していない。
      #
      # 本家 (spree_admin 5.3.6) の build_or_grouping には2つの問題がある:
      #
      # 1. p (述語) と v (値) を a (属性) の内側に入れている。
      #    ransack は a と兄弟の階層に p / v を期待するため、grouping ごと黙って無視される
      #    (= 全件が返る)。
      # 2. 述語を operator.to_s.sub('_', '') で作っており、最初の _ を落としてしまう。
      #    not_eq → "noteq"、not_cont → "notcont" のように不正な述語になる。
      #
      # @see https://github.com/be-agile/giga-repeat/issues/1262
      module FilterGroupDecorator
        private

        # @gem-override spree_admin-5.3.6/app/models/spree/admin/table/filter_group.rb#build_or_grouping
        # @see https://github.com/be-agile/giga-repeat/issues/1262
        def build_or_grouping(group)
          conditions = {}

          group.filters.each_with_index do |filter, index|
            param = filter.to_ransack_param
            next if param.empty?

            conditions[index.to_s] = {
              a: { '0' => { name: filter.field } },
              p: ransack_predicate_for(filter),
              v: ransack_values_for(param.values.first)
            }
          end

          {
            m: 'or',
            c: conditions
          }
        end

        # ransack の述語名 (先頭の _ を除いた OPERATORS の predicate)
        # @return [String]
        def ransack_predicate_for(filter)
          predicate = Spree::Admin::Table::Filter::OPERATORS.dig(filter.operator, :predicate)
          predicate.to_s.delete_prefix('_')
        end

        # ransack の値。in / not_in のように配列を取る述語では、値をまとめて1つの v に入れると
        # マッチしなくなる (0件になる) ため、要素ごとに v のエントリを作る。
        # @return [Hash]
        def ransack_values_for(value)
          values = value.is_a?(Array) ? value : [ value ]
          # 値が未入力 (空配列) の場合は空の v を作らない。nil を渡せば ransack がその条件を無視する
          values = [ nil ] if values.empty?

          values.each_with_index.to_h { |item, index| [ index.to_s, { value: item } ] }
        end
      end
    end
  end
end

Spree::Admin::Table::FilterGroup.prepend(Spree::Admin::Table::FilterGroupDecorator)
