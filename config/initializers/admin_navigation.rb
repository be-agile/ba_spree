# frozen_string_literal: true

# Spree 5.2 の新ナビゲーションシステム(legacy_sidebar_navigation=false)に対応。
# 旧来 ba_spree は _promotions_nav.html.erb の gem-override で販促サブメニュー
# (特価スケジュール / ボリュームディスカウント段階 / 金額帯割引)を追加していたが、
# 新システムでは legacy の _promotions_nav 自体がレンダリングされず無視される。
# そのため Spree.admin.navigation.sidebar に promotions の子メニューとして登録し直す。
# (gift_cards は本家が既定で登録済みのため対象外)
Rails.application.config.after_initialize do
  next unless Spree.admin.navigation.sidebar.exists?(:promotions)

  sidebar = Spree.admin.navigation.sidebar

  if defined?(Spree::ScheduledDiscount)
    sidebar.add :scheduled_discounts,
                parent: :promotions,
                label: :scheduled_discounts,
                url: :admin_scheduled_discounts_path,
                position: 20,
                active: -> { controller_name == 'scheduled_discounts' },
                if: -> { can?(:manage, Spree::Promotion) }
  end

  if defined?(Spree::VolumeDiscountTierGroup)
    sidebar.add :volume_discount_tier_groups,
                parent: :promotions,
                label: :volume_discount_tier_groups,
                url: :admin_volume_discount_tier_groups_path,
                position: 30,
                active: -> { controller_name == 'volume_discount_tier_groups' },
                if: -> { can?(:manage, Spree::Promotion) }
  end

  if defined?(Spree::AmountDiscountTierGroup)
    sidebar.add :amount_discount_tier_groups,
                parent: :promotions,
                label: :amount_discount_tier_groups,
                url: :admin_amount_discount_tier_groups_path,
                position: 40,
                active: -> { controller_name == 'amount_discount_tier_groups' },
                if: -> { can?(:manage, Spree::Promotion) }
  end
end
