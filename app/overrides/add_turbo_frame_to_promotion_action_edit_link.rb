# @gem-override spree_admin-5.3.6/app/views/spree/admin/promotion_actions/_promotion_action.html.erb
# reason: プロモーションアクションの「編集」リンクに data-turbo-frame を付与する。
#   本家は各アクションを turbo_frame_tag promotion_action(=dom_id) で囲み、編集リンクは
#   その frame 内クリックでインライン編集(モーダル相当)される想定だが、dropdown が
#   Floating UI でメニューを body 直下へ portal するため、編集リンクが frame の外に出てしまい、
#   data-turbo-frame 無指定だとフルページ遷移(/promotion_actions/:id/edit)になり、更新後も
#   プロモーション画面へ戻らない。対象 frame を明示してインライン編集に戻す。
#   (削除リンクは元から turbo_frame: '_top' 指定があり影響なし)
#
# Spree 5.3 追従: 本家は dropdown に portal: false を追加し、メニューを body 直下へ portal しなくなった。
#   これにより本来の不具合は本家側で解消し得るが、selector(edit_admin_promotion_action_path を含む erb)は
#   5.3 でも存在しマッチするため、安全側に倒して override を維持する(turbo_frame 明示は無害)。
Deface::Override.new(
  virtual_path: 'spree/admin/promotion_actions/_promotion_action',
  name: 'add_turbo_frame_to_promotion_action_edit_link',
  replace: "erb[loud]:contains('edit_admin_promotion_action_path')",
  text: <<-ERB
    <%= link_to_with_icon 'pencil', Spree.t('actions.edit'), spree.edit_admin_promotion_action_path(promotion_action.promotion, promotion_action), class: 'dropdown-item', data: { turbo_frame: dom_id(promotion_action) } if can?(:update, promotion_action) %>
  ERB
)
