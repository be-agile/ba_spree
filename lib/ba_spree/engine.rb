module BaSpree
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'ba_spree'

    config.autoload_paths += %W(#{config.root}/lib)

    initializer 'ba_spree.autoloader' do |app|
      if Rails.autoloaders.zeitwerk_enabled?
        Rails.autoloaders.main.ignore("#{root}/app/overrides")
      end
    end

    # Spree 5.3 のイベント subscriber 二重登録（注文確認/キャンセルメールの多重送信）対策。
    # subscriber 登録（after_initialize 内の Spree::Events.activate!）より前に適用する必要があるため
    # initializer で require する。 @see https://github.com/be-agile/giga-repeat/issues/1230
    initializer 'ba_spree.spree_events_dedup_patch' do
      require 'ba_spree/spree_events_dedup_patch'
    end

    initializer 'ba_spree.importmap', before: 'importmap' do |app|
      app.config.importmap.paths << root.join('config/importmap.rb')
      app.config.importmap.cache_sweepers << root.join('app/assets/javascripts')
      app.config.importmap.cache_sweepers << root.join('app/javascript')
    end

    initializer 'ba_spree.assets' do |app|
      app.config.assets.paths << root.join('app/javascript')
      app.config.assets.precompile += %w( spree/admin/custom.css )
    end

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.configuration.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare &method(:activate).to_proc
  end
end
