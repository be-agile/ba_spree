# payment 画面の請求先住所(bill_address)フォームは「配送先と同じ(use_shipping)」のとき
# hidden クラスで隠されるが、中の firstname_kana / lastname_kana などには required が
# 付いたまま残る。空のまま「保存して続ける」を押すと HTML5 バリデーションが非表示の
# required フィールドを検証しようとし "An invalid form control ... is not focusable" で
# submit が完全に中止される(POST が一切飛ばない)。
#
# disable-when-hidden コントローラを付与し、非表示の間は中の入力欄を disabled にして
# 検証・送信の対象から外す。表示に戻れば disabled を解除して挙動を元に戻す。
# @see https://github.com/be-agile/giga-repeat/issues/1210
Deface::Override.new(
  virtual_path: 'spree/checkout/_payment',
  name: 'disable_hidden_bill_address_fields_on_payment',
  add_to_attributes: "div[data-toggle-target='toggleable']",
  attributes: { 'data-controller': 'disable-when-hidden' }
)
