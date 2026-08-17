# @gem-override spree_admin-5.3.6/app/views/spree/admin/orders/_line_item.html.erb
# reason: 注文明細(line_item)の「編集」リンクに data-turbo-frame を付与する。
#   本家は各明細を turbo_frame_tag dom_id(line_item) で囲み、編集リンクはその frame 内クリックで
#   インライン編集される想定だが、dropdown が Floating UI でメニューを body 直下へ portal するため、
#   編集リンクが frame の外に出てしまい、data-turbo-frame 無指定だとフルページ遷移になる。
#   (同種の不具合をプロモーションのルール/アクション編集でも修正済み)
#   対象 frame を明示してインライン編集に戻す。
#
# Spree 5.3 追従: 本家は dropdown に portal: false を追加し、メニューを body 直下へ portal しなくなった。
#   これにより本来の不具合は本家側で解消し得るが、selector(edit_admin_order_line_item_path を含む erb)は
#   5.3 でも存在しマッチするため、安全側に倒して override を維持する(turbo_frame 明示は無害)。
Deface::Override.new(
  virtual_path: 'spree/admin/orders/_line_item',
  name: 'add_turbo_frame_to_admin_order_line_item_edit_link',
  replace: "erb[loud]:contains('edit_admin_order_line_item_path')",
  text: <<-ERB
    <%= link_to_with_icon "edit",
      Spree.t(:edit),
      spree.edit_admin_order_line_item_path(@order, line_item),
      class: "dropdown-item",
      data: { turbo_frame: dom_id(line_item) } %>
  ERB
)
