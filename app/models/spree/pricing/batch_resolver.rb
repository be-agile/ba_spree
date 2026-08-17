module Spree
  module Pricing
    # 1商品の全 variant について、適用される実価格をまとめて解決する。
    #
    # 本家の Resolver は variant ごとに price_list の適用判定とクエリ(または Rails.cache 往復)を
    # 行うため、多 variant 商品ではフラグメントキャッシュが冷えた際の一覧描画が極端に遅くなる。
    # price_list の適用判定は variant に依存しない(active/scheduled + 期間 + rules のみ)ので、
    # 商品ごとに1回だけ判定し、全 variant の価格をまとめて読んでから選び直す。
    #
    # 価格の選択規則は Resolver から複製しているため、Spree アップグレード時は各メソッドの
    # @gem-override マーカーで本家の変更(rake gem_override_marker:diff / :check)を確認すること。
    # @see https://github.com/be-agile/giga-repeat/issues/1290
    class BatchResolver
      attr_reader :variants, :context

      # @param variants [Array<Spree::Variant>] master を含む解決対象の variant
      # @param context [Spree::Pricing::Context] 商品共通の価格解決コンテキスト
      def initialize(variants:, context:)
        @variants = variants
        @context = context
      end

      # @return [Array<Spree::Price>] amount が確定した価格のみ(価格未設定の variant は除外)
      def resolve
        return [] if variants.empty?

        price_list_ids = applicable_price_lists.map(&:id)
        prices_by_variant_id = prices_by_variant_id_for(currency)

        variants.filter_map do |variant|
          find_best_price(prices_by_variant_id[variant.id] || [], price_list_ids)
        end
      end

      private

      def currency
        @currency ||= context.currency&.upcase
      end

      # @gem-override spree_core-5.3.6/lib/spree/core/pricing/resolver.rb#find_best_price
      # reason: 本家は variant ごとに price_list を1件ずつ照会するが、ここでは読み込み済みの価格配列と
      #   商品単位で判定済みの price_list id から同じ優先順位で選ぶ。本家の find_price_for_list
      #   (.non_zero) と find_base_price (amount present) の条件もこのメソッドに畳んである。
      # @see https://github.com/be-agile/giga-repeat/issues/1290
      # @param prices [Array<Spree::Price>] その variant の該当通貨の価格
      # @param price_list_ids [Array] 適用される price_list の id(position 昇順)
      # @return [Spree::Price, nil]
      def find_best_price(prices, price_list_ids)
        price_list_ids.each do |price_list_id|
          price = prices.find do |candidate|
            candidate.price_list_id == price_list_id && candidate.amount.present? && !candidate.amount.zero?
          end
          return price if price
        end

        prices.find { |price| price.price_list_id.nil? && price.amount.present? }
      end

      # @gem-override spree_core-5.3.6/lib/spree/core/pricing/resolver.rb#applicable_price_lists
      # reason: 本家は variant ごとの Resolver インスタンス単位でメモ化するが、適用判定は variant に
      #   依存しないため商品単位(このインスタンス)で1回だけ評価する。判定そのものは本家と同一。
      # @see https://github.com/be-agile/giga-repeat/issues/1290
      # @return [Array<Spree::PriceList>]
      def applicable_price_lists
        @applicable_price_lists ||= price_lists_for_context.select { |price_list| price_list.applicable?(context) }
      end

      # @gem-override spree_core-5.3.6/lib/spree/core/pricing/resolver.rb#price_lists_for_context
      # reason: 本家と同一。Resolver を経由しないため取得元の分岐だけ複製している。
      # @see https://github.com/be-agile/giga-repeat/issues/1290
      # @return [Enumerable<Spree::PriceList>]
      def price_lists_for_context
        if context.store == Spree::Current.store && context.currency == Spree::Current.currency
          Spree::Current.price_lists
        else
          Spree::PriceList.for_context(context)
        end
      end

      # variant_id ごとの該当通貨の価格。未ロードの variant があれば1クエリでまとめて読む。
      # 通貨の比較は、本家が SQL(with_currency)で行い spree_prices の照合順序が
      # utf8mb4_general_ci = 大文字小文字を区別しないため、Ruby 側でも区別しない。
      # @param currency [String]
      # @return [Hash]
      def prices_by_variant_id_for(currency)
        unloaded = variants.reject { |variant| variant.association(:prices).loaded? }
        ActiveRecord::Associations::Preloader.new(records: unloaded, associations: :prices).call if unloaded.any?

        variants.to_h do |variant|
          [ variant.id, variant.prices.select { |price| price.currency&.casecmp?(currency) } ]
        end
      end
    end
  end
end
