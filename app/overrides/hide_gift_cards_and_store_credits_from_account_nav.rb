Deface::Override.new(
  virtual_path: "spree/account/_account_nav",
  name: "hide_gift_cards_menu_from_account_nav",
  remove: "erb[loud]:contains('account_gift_cards_path')"
)

Deface::Override.new(
  virtual_path: "spree/account/_account_nav",
  name: "hide_store_credits_menu_from_account_nav",
  remove: "erb[loud]:contains('account_store_credits_path')"
)
