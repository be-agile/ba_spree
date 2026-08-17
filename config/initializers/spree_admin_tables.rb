# frozen_string_literal: true

# Spree 5.3 追従: admin 一覧テーブル(Spree.admin.tables.*)の表示調整
#
# Spree 5.3 で admin の一覧は _list.html.erb ではなくテーブルレジストリ
# (Spree.admin.tables.*)のカラム定義で描画される。gem 既定の挙動が日本語 UI と
# 合わない箇所を、ここでカラム属性を上書きして補正する。
#
#  (1) 日時列(type: :datetime): 既定は :spree_time_ago で「yesterday at 8:29am」
#      「on Dec 10, 2025」のような英語相対表示+ホバーで絶対日時。最初から日本語の絶対日時
#      (例 2026年06月11日 00:29)を出すため、format に :spree_time を指定して相対表示
#      フォーマッタを差し替える。注文一覧の完了日時・ユーザー/ニュースレター購読者の作成日時等、
#      全 admin 一覧テーブルの datetime 列をまとめて対象にする(format 明示済みの列は尊重)。
#  (2) アイテム数(orders.item_count): 既定の method は `pluralize(item_count, 'item')` で
#      「330 item」と英語表示。「330個」にするため method を差し替える。
#      見出し(label: :item_count → Spree.t(:item_count) = ja.spree.item_count)は
#      config/locales/spree.ja.yml で「個数」に変更済み(本ファイルでは値の表示のみ変更)。
Rails.application.config.after_initialize do
  # (1) 全 admin 一覧テーブルの datetime 列を日本語の絶対日時表示にする
  Spree.admin.tables.registries.each do |table_key|
    table = Spree.admin.tables.get(table_key)
    table.columns.each_value do |column|
      next unless column.type.to_s == 'datetime'
      next if column.format.present? # 個別に書式指定済みの列は触らない

      column.format = :spree_time
    end
  end

  # (2) 注文一覧のアイテム数を「330個」表示にする
  orders = Spree.admin.tables.get(:orders)
  if (item_count = orders&.columns&.[](:item_count))
    item_count.method = ->(order) { "#{order.item_count}個" }
  end
end

# (3) ページネーション文言(「Displaying items 1-25 of 13119 in total」)の日本語化
#
# spree_admin 5.3 の一覧フッターは Pagy の @pagy.info_tag で描画される。Pagy は Rails の
# I18n とは独立した独自 i18n(Pagy::I18n、Thread ローカル :pagy_locale)を持ち、既定が 'en' の
# ため英語表示になる。Pagy gem には日本語辞書(pagy/locales/ja.yml)が同梱されているので、
# 各リクエストで Pagy のロケールを Rails の I18n.locale に追従させれば日本語になる。
# I18n.locale= をフックして両者を常に同期させる(storefront/admin 双方をカバー)。
require 'pagy'

module BaSpree
  module PagyLocaleSync
    def locale=(value)
      super
      Pagy::I18n.locale = value.to_s
    end
  end
end

I18n.singleton_class.prepend(BaSpree::PagyLocaleSync)
# 初期化時点の locale も同期しておく
Pagy::I18n.locale = I18n.locale.to_s
