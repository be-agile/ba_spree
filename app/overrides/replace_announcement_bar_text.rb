Deface::Override.new(
  virtual_path: "spree/page_sections/_announcement_bar",
  name: "replace_announcement_bar_text",
  replace: "div.tracking-widest",
  text: "<div class='tracking-widest w-full'><%= CGI.unescapeHTML(section.text.body.to_s).html_safe %></div>"
)
