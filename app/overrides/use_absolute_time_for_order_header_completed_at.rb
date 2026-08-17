# frozen_string_literal: true

# Spree 5.3 追従: 注文詳細ヘッダーの「完了日時」を日本語の絶対日時で表示する
#
# spree_admin 5.3 の orders/_header.html.erb は完了日時を spree_time_ago で描画するため、
# 「yesterday at 8:29am」のような英語相対表示+ホバーで絶対日時、となる。
# 日本語の絶対日時(例 2026年06月11日 08:29)を最初から表示するため spree_time に差し替える。
# (注文一覧テーブルの completed_at 列は config/initializers/spree_admin_orders_table.rb で
#  format: :spree_time として同等の対応済み)
Deface::Override.new(
  virtual_path: 'spree/admin/orders/_header',
  name: 'use_absolute_time_for_order_header_completed_at',
  replace: "erb[loud]:contains('spree_time_ago')",
  text: '<%= spree_time(@order.completed_at) %>'
)
