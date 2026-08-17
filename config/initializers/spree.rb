# 日本の EC では注文確定前に内容確認画面を挟むのが一般的なため、
# confirm ステップを常に有効にする。
# @see https://github.com/be-agile/giga-repeat/issues/1317
Spree.config do |config|
  config.always_include_confirm_step = true
end
