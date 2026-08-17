# frozen_string_literal: true

module Spree
  module Admin
    # 表示件数 (per page) のリンクに query_state を引き継ぐ。
    # @see Spree::Admin::FilterParamsPreservation
    # @see https://github.com/be-agile/giga-repeat/issues/1262
    module NavigationHelperDecorator
      include Spree::Admin::FilterParamsPreservation

      # 本家は request.query_parameters.slice(:q) しか引き継がないため query_state が落ちる。
      # q は残るので結果は絞り込まれたままだが、フィルターの件数バッジとドロワーが空になってしまう。
      # あわせて、OR グループで壊れた ransack キーが URL に載らないようにする。
      def per_page_dropdown_params(per_page)
        dropdown_params = super
        dropdown_params[:q] = preserved_ransack_params if dropdown_params[:q].present?
        dropdown_params.merge(preserved_query_state_param)
      end
    end
  end
end

Spree::Admin::NavigationHelper.prepend(Spree::Admin::NavigationHelperDecorator)
