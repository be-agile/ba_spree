# payment 画面で請求先住所(bill_address)を新規入力して送信し、バリデーションで差し戻された
# とき、本家は bill_address が new_record? のため「配送先と同じ(use_shipping)」を再びチェック
# 済みにし、入力したフォームを hidden に戻してしまう。入力欄の直下に出したエラーも一緒に
# 隠れて、何が悪かったのか分からなくなる。
#
# 請求先住所にエラーがあるときは use_shipping を外し、フォームを開いたままにする。
# @see https://github.com/be-agile/giga-repeat/issues/1397
Deface::Override.new(
  virtual_path: 'spree/checkout/_payment',
  name: 'keep_bill_address_form_open_on_error',
  replace: "erb[silent]:contains('use_shipping = ')",
  text: "<% use_shipping = (@order.shipping_eq_billing_address? || @order.bill_address.nil? || @order.bill_address.new_record?) && @order.requires_ship_address? && (@order.bill_address.nil? || @order.bill_address.errors.empty?) %>"
)
