module BaSpree
  module StoreDecorator
    def self.prepended(base)
      base.has_rich_text :special_instruction_message

      base.class_eval do
        # @gem-override spree_core-5.3.6/app/models/spree/store.rb#default
        # @see https://github.com/be-agile/giga-repeat/commit/b7c74b2a1f45555616c19f3788def6aa3f67a7a1
        # 本家は default フラグが無ければ DB の最初の1件を返すが、ba_spree では
        # 該当が無いとき新規 default インスタンスを返す（マルチテナントで未作成テナント対策）。
        def self.default
          if where(default: true).any?
            where(default: true).first
          else
            new(default: true)
          end
        end
      end
    end
  end
end

Spree::Store.prepend BaSpree::StoreDecorator
