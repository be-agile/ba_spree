# 会員登録フォームのバリデーションエラーを画面に表示するためのオーバーライド。
#
# spree_storefront の devise/registrations/new はフォームを turbo_frame_tag :login で囲み、
# data: { turbo_frame: '_top' } で送信する。この状態でサーバが 422 を返すと、レスポンスは
# turbo-frame レイアウトで描画される（error_messages パーシャルは含まれる）が、フォームは
# _top を狙うため Turbo がフレーム応答を反映できず、エラーが画面に出ないまま再描画される。
#
# パスワード変更フォーム(edit)は data: { turbo: false } で通常の全画面再描画となりエラーが
# 表示されるため、それに合わせて登録フォームも Turbo を無効化し、エラーを表示できるようにする。
# @see https://github.com/be-agile/giga-repeat/issues/1216
Deface::Override.new(
  virtual_path: "devise/registrations/new",
  name: "disable_turbo_on_user_registration_form",
  replace: "erb[loud]:contains('form_for(resource')",
  text: <<~ERB
    <%= form_for(resource, as: resource_name, url: registration_path(resource_name), data: { turbo: false }) do |f| %>
  ERB
)
