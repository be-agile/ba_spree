module BaSpree
  # Spree のストアを日本仕様に初期設定する。
  #
  # 扱うのは「日本で EC を始めるなら誰でも必要になる設定」だけで、
  # ストア名・URL・メールアドレスといった各ショップ固有の情報には触れない。
  # それらは呼び出し側が設定する。
  #
  # @see https://github.com/be-agile/giga-repeat/issues/1317
  class SetupService
    # 国マスタ (Spree の seed が作る) が無いときに投げる
    class CountryNotFoundError < StandardError; end

    COUNTRY_NOT_FOUND_MESSAGE =
      "日本 (iso: JP) が spree_countries に見つかりません。先に `rails db:seed` を実行してください。".freeze

    PREFECTURES = [
      "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県", "茨城県", "栃木県", "群馬県",
      "埼玉県", "千葉県", "東京都", "神奈川県", "新潟県", "富山県", "石川県", "福井県", "山梨県",
      "長野県", "岐阜県", "静岡県", "愛知県", "三重県", "滋賀県", "京都府", "大阪府", "兵庫県",
      "奈良県", "和歌山県", "鳥取県", "島根県", "岡山県", "広島県", "山口県", "徳島県", "香川県",
      "愛媛県", "高知県", "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県"
    ].freeze

    # Spree::Seeds::Zones が作る海外向けゾーン全7種。日本国内向けストアでは不要なので削除する。
    # @see spree_core-5.3.6/app/services/spree/seeds/zones.rb
    FOREIGN_ZONE_NAMES = [
      "EU_VAT", "UK_VAT", "North America", "South America",
      "Middle East", "Asia", "Australia and Oceania"
    ].freeze

    # 標準税率。配送料の税区分にも使う
    STANDARD_TAX_CODE = "consumption10".freeze

    TAX_RATES = [
      { amount: 0.1, name: "消費税10%", code: STANDARD_TAX_CODE },
      # 軽減税率 (飲食料品・定期購読の新聞)
      { amount: 0.08, name: "消費税8%", code: "consumption8" },
      { amount: 0, name: "消費税非課税", code: "consumption0" }
    ].freeze

    ZONE_NAME = "日本".freeze
    SHIPPING_METHOD_CODE = "fixed".freeze
    SHIPPING_RATE = 500
    SAGAWA_TRACKING_URL = "https://k2k.sagawa-exp.co.jp/p/web/okurijosearch.do?okurijoNo=:tracking".freeze

    class << self
      # @param store [Spree::Store] 日本仕様に設定するストア
      # @param load_seed [Boolean] Spree の seed (国マスタ等) を先に流すか
      def setup(store:, load_seed: true)
        Spree::Core::Engine.load_seed if load_seed

        japan = setup_country
        zone = setup_zone(japan)
        setup_tax_rates(zone)
        setup_store(store, japan, zone)
        setup_shipping_method(zone)
        store
      end

      private

      # 国マスタは Spree の seed が作る。load_seed: false で呼ぶ場合は
      # 事前に `rails db:seed` を済ませておく必要があるため、
      # 見つからなければ理由の分かる例外で止める。
      def setup_country
        japan = Spree::Country.find_by(iso: "JP")
        raise CountryNotFoundError, COUNTRY_NOT_FOUND_MESSAGE if japan.nil?

        japan.update(states_required: true)
        PREFECTURES.each do |prefecture|
          Spree::State.find_or_create_by(name: prefecture, country: japan, abbr: prefecture)
        end
        japan
      end

      def setup_zone(japan)
        FOREIGN_ZONE_NAMES.each { |name| Spree::Zone.find_by(name: name)&.destroy }

        zone = Spree::Zone.find_or_create_by(name: ZONE_NAME, description: "", default_tax: true, kind: "country")
        zone.zone_members = [ Spree::ZoneMember.new(zoneable: japan) ]
        zone.save
        zone
      end

      def setup_tax_rates(zone)
        TAX_RATES.each do |attr|
          # is_default は検索条件に含めない。Spree::TaxCategory#set_default_category が
          # 「default は1つだけ」を保つため他カテゴリの is_default を false に落とすので、
          # 条件に含めると2回目以降マッチせず重複レコードが増える
          tax_category = Spree::TaxCategory.find_or_create_by!(name: attr[:name], tax_code: attr[:code]) do |category|
            category.description = ""
            category.is_default = true
          end
          tax_rate = Spree::TaxRate.find_or_initialize_by(
            amount: attr[:amount],
            zone: zone,
            tax_category: tax_category,
            included_in_price: true,
            name: "消費税",
            show_rate_in_label: true)
          tax_rate.calculator = Spree::Calculator::DefaultTax.new
          tax_rate.save
        end
      end

      # 通貨・ロケール・課税ゾーンなど、日本で運用するうえで必要な設定のみを行う。
      # ストア名・URL・メールアドレスは各ショップ固有の情報なので呼び出し側の責務とする。
      def setup_store(store, japan, zone)
        store.default_currency = "JPY"
        store.supported_currencies = "JPY"
        store.supported_locales = "ja"
        store.default_country = japan
        store.checkout_zone = zone
        store.save
      end

      def setup_shipping_method(zone)
        tax_category = Spree::TaxCategory.find_by(tax_code: STANDARD_TAX_CODE)
        shipping_method = Spree::ShippingMethod.find_or_initialize_by(
          name: "配送料",
          display_on: "both",
          tracking_url: SAGAWA_TRACKING_URL,
          admin_name: "配送料(定額)",
          tax_category: tax_category,
          code: SHIPPING_METHOD_CODE)
        shipping_method.shipping_categories = [ default_shipping_category ]
        calculator = Spree::Calculator::Shipping::FlatRate.new
        calculator.preferred_currency = "JPY"
        calculator.preferred_amount = SHIPPING_RATE
        shipping_method.calculator = calculator
        shipping_method.save
        Spree::ShippingMethodZone.create(shipping_method: shipping_method, zone: zone)
        shipping_method
      end

      # Spree の seed が作る既定の配送カテゴリ。
      # 名前は spree.seed.shipping.categories.default の訳 (日本語なら「既定」) になるが、
      # seed 未実行だと存在しないため、無ければここで作る。
      def default_shipping_category
        Spree::ShippingCategory.find_or_create_by!(name: I18n.t("spree.seed.shipping.categories.default"))
      end
    end
  end
end
