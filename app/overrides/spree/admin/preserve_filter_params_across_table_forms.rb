# frozen_string_literal: true

# 一覧テーブルのツールバーにある「検索」「期間」「フィルタービルダー」は独立した GET フォームで、
# 送信すると他のフォームの絞り込み条件が URL から消えてしまう。
# 各フォームに、自分が送信しないパラメータを hidden input として持たせて併用できるようにする。
# @see https://github.com/be-agile/giga-repeat/issues/1262

# 検索フォーム: 期間・フィルターを引き継ぐ
Deface::Override.new(
  virtual_path: 'spree/admin/tables/_table',
  name: 'preserve_filter_params_in_table_search_form',
  insert_bottom: 'div.form-input',
  text: <<~ERB
    <%= preserved_filter_params_inputs(except_q: [search_param]) %>
  ERB
)

# 期間フォーム: 検索・フィルターを引き継ぐ
Deface::Override.new(
  virtual_path: 'spree/admin/tables/_table',
  name: 'preserve_filter_params_in_table_date_range_form',
  insert_after: "erb[loud]:contains('calendar_range_picker')",
  text: <<~ERB
    <%= preserved_filter_params_inputs(except_q: ["\#{date_range_param}_gt", "\#{date_range_param}_lt"]) %>
  ERB
)

# フィルタービルダーのフォーム: 検索・期間を引き継ぐ
# (query_state 由来の q[...] は JS が生成し直すため、ここでは引き継がない)
Deface::Override.new(
  virtual_path: 'spree/admin/tables/_query_builder',
  name: 'preserve_filter_params_in_table_query_builder_form',
  insert_after: 'input[name="query_state"]',
  text: <<~ERB
    <%= preserved_filter_params_inputs(owns_query_state: true, table: table) %>
  ERB
)

# ページネーションのリンク: 壊れた ransack キー (OR グループ) を URL に載せない。
# 本家は url_for(request.query_parameters.merge(page: ...)) で、壊れたキーを名前を変質させながら
# 引き回してしまう。
Deface::Override.new(
  virtual_path: 'spree/admin/shared/_index_table_options',
  name: 'sanitize_ransack_params_in_pagination_previous_link',
  replace: "erb[loud]:contains('@pagy.previous')",
  text: <<~ERB
    <%= link_to icon('chevron-left', class: 'text-gray-900 mr-0'),
        url_for(preserved_pagination_params(@pagy.previous)),
        class: "btn btn-light p-2",
        'aria-label': 'Previous page' %>
  ERB
)

Deface::Override.new(
  virtual_path: 'spree/admin/shared/_index_table_options',
  name: 'sanitize_ransack_params_in_pagination_next_link',
  replace: "erb[loud]:contains('@pagy.next')",
  text: <<~ERB
    <%= link_to icon('chevron-right', class: 'text-gray-900 mr-0'),
        url_for(preserved_pagination_params(@pagy.next)),
        class: "btn btn-light p-2",
        'aria-label': 'Next page' %>
  ERB
)
