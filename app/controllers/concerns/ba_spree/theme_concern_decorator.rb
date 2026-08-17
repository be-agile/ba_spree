module BaSpree
  module ThemeConcernDecorator
    # @gem-override spree_storefront-5.3.6/app/controllers/concerns/spree/theme_concern.rb#set_theme_view_paths
    # reason: 本家の view path 設定 (super) の後に、ba_spree extension の themes/default を
    #   view path に追加して本家テーマより優先させる (commit d0f0ce22)
    # @see https://github.com/be-agile/giga-repeat/commit/d0f0ce224dd5696b38676f2fe4dc1e52743f115a
    def set_theme_view_paths
      super
      prepend_view_path [ BaSpree::Engine.root, 'app/views/themes/default' ].join('/')
    end
  end
end

if Spree::ThemeConcern.included_modules.exclude?(BaSpree::ThemeConcernDecorator)
  Spree::ThemeConcern.prepend BaSpree::ThemeConcernDecorator
end
