Deface::Override.new(
  virtual_path: "devise/shared/_links",
  name: "add_class_to_login_link",
  replace: "erb[loud]:contains('link_to Spree.t(:login)')",
  text: "<%= link_to Spree.t(:login), new_session_path(resource_name), class: 'btn btn-secondary' %>"
)
