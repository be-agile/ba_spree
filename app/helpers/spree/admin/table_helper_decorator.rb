# frozen_string_literal: true

module Spree
  module Admin
    # 一覧テーブルの絞り込み条件を引き継ぐ。
    # ビューからは preserved_filter_params_inputs を使う (Deface で各フォームに差し込んでいる)。
    # @see Spree::Admin::FilterParamsPreservation
    # @see https://github.com/be-agile/giga-repeat/issues/1262
    module TableHelperDecorator
      include Spree::Admin::FilterParamsPreservation

      private

      # 並び替えリンクに query_state を引き継ぐ。
      #
      # 本家は url_for(q: ...) でリンクを組むため query_state が落ちる。q は残るので結果は
      # 絞り込まれたままだが、フィルターの件数バッジとドロワーが空になってしまう。
      #
      # 引数の current_q (= params[:q]) はコントローラが query_state 由来の条件をマージした後の値で、
      # OR グループの grouping が丸ごと展開されてリンクが肥大する。URL 生の q を使えば
      # 表示件数・ページネーションのリンクと同じ内容になり、条件は query_state から再生成される。
      #
      # @gem-override spree_admin-5.3.6/app/helpers/spree/admin/table_helper.rb#sort_dropdown_item
      # @see https://github.com/be-agile/giga-repeat/issues/1262
      def sort_dropdown_item(label, sort_value, is_active, _current_q)
        sort_params = preserved_query_state_param.merge(q: preserved_ransack_params.merge(s: sort_value))

        link_to(
          url_for(sort_params),
          class: "dropdown-item flex items-center justify-between #{'active' if is_active}",
          data: { turbo_action: 'advance' }
        ) do
          safe_join([ content_tag(:span, label), is_active ? icon('check') : '' ])
        end
      end
    end
  end
end

Spree::Admin::TableHelper.prepend(Spree::Admin::TableHelperDecorator)
