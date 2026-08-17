pin "local-time"
pin 'ba-spree-local-time', to: 'ba_spree/storefront/ba_spree_local_time.js', preload: false

# Stimulus コントローラーエントリーポイント (storefront)
pin 'ba_spree', to: 'ba_spree/index.js', preload: true

# Stimulus コントローラー
# Engine.root は初期化時に使えないため __dir__ を使用する
pin_all_from File.expand_path('../app/javascript/ba_spree/controllers', __dir__),
             under: 'ba_spree/controllers',
             to: 'ba_spree/controllers',
             preload: false
