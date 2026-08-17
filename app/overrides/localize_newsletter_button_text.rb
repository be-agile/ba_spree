Deface::Override.new(
  virtual_path: "spree/account/newsletter/_newsletter_settings",
  name: "localize_newsletter_button_text",
  replace: "erb[loud]:contains('@user.accepts_email_marketing?')",
  text: "<%= @user.accepts_email_marketing? ? Spree.t(:unsubscribe) : Spree.t(:subscribe) %>"
)
