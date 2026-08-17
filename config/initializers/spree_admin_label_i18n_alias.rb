# frozen_string_literal: true

# Spree 5.3 追従: admin テーブルの列見出し等のラベル英語化対策
#
# spree_admin 5.3 の Spree::Admin::Table::Column#resolve_label は
# `label:` がドットを含む文字列(例: 'admin.num_orders')のとき、
# spree 名前空間を付けずに素の I18n.t を呼ぶ:
#
#   return I18n.t(label, default: label.split('.').last.humanize) if label.is_a?(String) && label.include?('.')
#
# このため `I18n.t('admin.num_orders')`(= ja.admin.num_orders)を引くが、
# 日本語訳は ja.spree.admin.* 配下にしか無く、英語(humanize フォールバック)
# になってしまう。num_orders / amount_spent の列見出し、各種一括操作ラベル、
# サイドナビ項目(getting_started, audit_log 等)が該当する。
#
# 訳語を二重管理しないため、ja.spree.admin をそのまま ja.admin にミラー登録して
# spree 接頭辞無しの参照を救済する(spree_admin gem 側の resolve_label の
# 仕様変更があれば本ファイルは不要になる)。
Rails.application.config.after_initialize do
  # Spree は I18n::Backend::Chain を使う。Chain#store_translations は
  # NotImplementedError を投げるため、チェイン内で実際に格納可能な
  # 具体バックエンド(Simple 等)を再帰的に探して登録する。
  find_storable = lambda do |backend|
    unless backend.is_a?(I18n::Backend::Chain)
      owner = backend.method(:store_translations).owner rescue nil
      return backend if owner && owner != I18n::Backend::Base
    end
    if backend.respond_to?(:backends)
      backend.backends.each do |child|
        found = find_storable.call(child)
        return found if found
      end
    end
    nil
  end

  target = find_storable.call(I18n.backend)

  if target
    %i[ja en].each do |locale|
      admin_translations = I18n.t('spree.admin', locale: locale, default: nil)
      next unless admin_translations.is_a?(Hash)

      # ja.admin が既に持つ独自定義を壊さないよう、spree.admin 側を下地にして
      # 既存の ja.admin を上書き優先でマージする。
      existing = I18n.t('admin', locale: locale, default: nil)
      merged = admin_translations.deep_merge(existing.is_a?(Hash) ? existing : {})

      target.store_translations(locale, { admin: merged })
    end
  end
end
