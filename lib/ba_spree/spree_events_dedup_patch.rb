# frozen_string_literal: true

# Spree 5.3 のイベント subscriber 登録に重複ガードが無い問題への対策。
#
# `spree_emails` の Engine#after_initialize は無条件で
# `Spree.subscribers.concat([Spree::OrderEmailSubscriber, ...])` を行い、
# `Spree::Events.register_subscribers!` は `Spree.subscribers` を `.uniq` せず反復、
# さらに `Spree::Events::Registry#register` も重複チェックをしない。
# このため何らかの理由で subscriber が二重に登録されると subscription も二重化し、
# 注文確認メール / キャンセルメールが 2 通ずつ送信される。
#
# resolve 後の subscriber クラス単位で重複排除し、同一 subscriber を
# 1 回しか登録しないようにする（環境非依存で堅牢）。
#
# @see https://github.com/be-agile/giga-repeat/issues/1230
module BaSpree
  # @gem-override spree_core-5.3.6/lib/spree/events.rb#register_subscribers!
  # @see https://github.com/be-agile/giga-repeat/issues/1230
  module SpreeEventsDedupPatch
    def register_subscribers!
      return unless defined?(Spree) && Spree.respond_to?(:subscribers)

      registered = []

      Spree.subscribers&.each do |subscriber|
        # Resolve the subscriber constant fresh to handle code reload in development
        # The array may contain stale class objects after Zeitwerk reload
        resolved_subscriber = resolve_subscriber(subscriber)
        next unless resolved_subscriber

        # 同一 subscriber を二重登録しない（subscription 二重化＝メール多重送信の防止）
        next if registered.include?(resolved_subscriber)

        registered << resolved_subscriber

        resolved_subscriber.subscription_patterns.each do |pattern|
          subscribe(pattern, resolved_subscriber, resolved_subscriber.subscription_options)
        end
      end
    end
  end
end

Spree::Events.singleton_class.prepend(BaSpree::SpreeEventsDedupPatch)
