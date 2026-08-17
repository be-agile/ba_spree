# frozen_string_literal: true

require 'rails_helper'

# Issue #1219: 価格表(price_list)を一覧・関連・セールラベルでログイン中ユーザのグループに
# 正しく反映させる。ゲスト/対象外ユーザに他グループの最安値・セールが漏れないこと、
# draft(草案)の price_list 価格がどのユーザにも漏れないことを検証する。
# @see https://github.com/be-agile/giga-repeat/issues/1219
RSpec.describe Spree::Product, type: :model do
  let!(:store) { create(:store, default: true) }
  let(:currency) { store.default_currency }

  # 定価 45815 の商品(master のみ)
  let(:product) { create(:product, stores: [ store ]) }
  let(:master) { product.master }

  let(:customer_group) { create(:customer_group, store: store) }
  let(:group_user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    Spree::Current.store = store
    Spree::Current.price_lists = nil
    Spree::Current.global_pricing_context = nil
    Spree::Current.pricing_user = nil

    master.prices.where(currency: currency, price_list_id: nil).update_all(amount: 45_815)
    create(:customer_group_user, customer_group: customer_group, user: group_user)
  end

  after { Spree::Current.reset }

  def with_user(user)
    Spree::Current.pricing_user = user
    Spree::Current.price_lists = nil
    yield
  end

  context 'active な price_list(顧客グループ向け・価格と価格で比較の両方を設定)があるとき' do
    let!(:price_list) do
      create(:price_list, :active, :any_match, store: store).tap do |pl|
        create(:customer_group_price_rule, price_list: pl, customer_group_ids: [ customer_group.id.to_s ])
        create(:price, variant: master, currency: currency, amount: 30_000,
                       compare_at_amount: 50_000, price_list_id: pl.id)
      end
    end

    it 'グループ内ユーザには price_list の価格(30000)とセール表示を返す' do
      with_user(group_user) do
        expect(product.lowest_price(currency).amount).to eq(30_000)
        expect(product.on_sale?(currency)).to be true
      end
    end

    it 'ゲストには定価(45815)を返し、セール表示しない' do
      with_user(nil) do
        expect(product.lowest_price(currency).amount).to eq(45_815)
        expect(product.on_sale?(currency)).to be false
      end
    end

    it '顧客グループ外ユーザには定価(45815)を返し、セール表示しない' do
      with_user(other_user) do
        expect(product.lowest_price(currency).amount).to eq(45_815)
        expect(product.on_sale?(currency)).to be false
      end
    end
  end

  context '複数グループの price_list があるとき' do
    let(:group_b) { create(:customer_group, store: store) }
    let(:group_b_user) { create(:user) }

    before do
      create(:customer_group_user, customer_group: group_b, user: group_b_user)

      pl_a = create(:price_list, :active, :any_match, store: store)
      create(:customer_group_price_rule, price_list: pl_a, customer_group_ids: [ customer_group.id.to_s ])
      create(:price, variant: master, currency: currency, amount: 30_000, price_list_id: pl_a.id)

      pl_b = create(:price_list, :active, :any_match, store: store)
      create(:customer_group_price_rule, price_list: pl_b, customer_group_ids: [ group_b.id.to_s ])
      create(:price, variant: master, currency: currency, amount: 40_000, price_list_id: pl_b.id)
    end

    it 'グループAユーザには30000、グループBユーザには40000を返す' do
      with_user(group_user)   { expect(product.lowest_price(currency).amount).to eq(30_000) }
      with_user(group_b_user) { expect(product.lowest_price(currency).amount).to eq(40_000) }
    end

    it 'ゲスト・対象外ユーザには定価(45815)を返す(他グループの最安値が漏れない)' do
      with_user(nil)        { expect(product.lowest_price(currency).amount).to eq(45_815) }
      with_user(other_user) { expect(product.lowest_price(currency).amount).to eq(45_815) }
    end
  end

  context 'draft(草案)の price_list があるとき' do
    before do
      pl = create(:price_list, :draft, :any_match, store: store)
      create(:customer_group_price_rule, price_list: pl, customer_group_ids: [ customer_group.id.to_s ])
      # draft なのでどのユーザにも適用されてはいけない
      create(:price, variant: master, currency: currency, amount: 1,
                     compare_at_amount: 99_999, price_list_id: pl.id)
    end

    it 'グループ内ユーザでも draft の価格(1円)は適用されず定価(45815)を返す' do
      with_user(group_user) do
        expect(product.lowest_price(currency).amount).to eq(45_815)
        expect(product.on_sale?(currency)).to be false
      end
    end

    it 'ゲストにも draft の価格は漏れず定価(45815)を返す' do
      with_user(nil) do
        expect(product.lowest_price(currency).amount).to eq(45_815)
        expect(product.on_sale?(currency)).to be false
      end
    end
  end

  # Issue #1290: variant ごとに Resolver を呼んでいた価格解決をバッチ解決へ置き換えた。
  # 表示価格・判定結果が旧実装と完全に一致すること、および解決コストが variant 数に
  # 比例しないことを検証する。
  # @see https://github.com/be-agile/giga-repeat/issues/1290
  describe 'バッチ価格解決' do
    # 旧実装と同じ手順(variant ごとに Resolver を呼ぶ)で期待値を求める
    def legacy_resolved_prices(currency)
      user = Spree::Current.pricing_user
      Spree::Product.find(product.id).variants_including_master.map do |variant|
        variant.price_for(Spree::Pricing::Context.new(variant: variant, currency: currency, user: user))
      end.select { |price| price&.amount.present? }
    end

    # メモ化の影響を避けるため、読み直したインスタンスで旧実装の結果と突き合わせる
    def expect_parity_with_legacy(currency)
      legacy = legacy_resolved_prices(currency)
      target = Spree::Product.find(product.id)

      expect(target.lowest_price(currency)&.amount).to eq(legacy.min_by(&:amount)&.amount)
      expect(target.price_varies?(currency)).to eq(legacy.map(&:amount).uniq.size > 1)
      expect(target.on_sale?(currency)).to eq(legacy.any?(&:discounted?))
    end

    # spree_prices を読むクエリ数を数える(spree_price_lists 等は対象外)
    def count_price_queries
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        count += 1 if payload[:sql].include?('spree_prices') && !payload[:cached]
      end
      yield
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end

    context 'price_list が無いとき' do
      it '旧実装と一致する' do
        expect_parity_with_legacy(currency)
      end
    end

    context '複数 variant で価格が異なるとき' do
      before do
        create(:variant, product: product, price: 20_000)
        create(:variant, product: product, price: 30_000)
      end

      it '旧実装と一致し、最安値20000・価格変動ありになる' do
        expect_parity_with_legacy(currency)
        expect(Spree::Product.find(product.id).lowest_price(currency).amount).to eq(20_000)
        expect(Spree::Product.find(product.id).price_varies?(currency)).to be true
      end
    end

    context '複数 variant で価格が同じとき' do
      before { 2.times { create(:variant, product: product, price: 45_815) } }

      it '旧実装と一致し、価格変動なしになる' do
        expect_parity_with_legacy(currency)
        expect(Spree::Product.find(product.id).price_varies?(currency)).to be false
      end
    end

    context '価格未設定の variant があるとき' do
      before do
        create(:variant, product: product, price: 20_000)
        create(:variant, product: product).prices.update_all(amount: nil)
      end

      it '旧実装と一致し、価格未設定 variant は最安値計算に混ざらない' do
        expect_parity_with_legacy(currency)
        expect(Spree::Product.find(product.id).lowest_price(currency).amount).to eq(20_000)
      end
    end

    context '定価に「価格で比較」が設定されているとき' do
      before do
        master.prices.where(currency: currency, price_list_id: nil).update_all(compare_at_amount: 60_000)
      end

      it '旧実装と一致し、セール表示になる' do
        expect_parity_with_legacy(currency)
        expect(Spree::Product.find(product.id).on_sale?(currency)).to be true
      end
    end

    context '期間内の scheduled な price_list があるとき' do
      before do
        price_list = create(:price_list, :any_match, store: store, status: 'scheduled',
                                                     starts_at: 1.day.ago, ends_at: 1.day.from_now)
        create(:customer_group_price_rule, price_list: price_list, customer_group_ids: [ customer_group.id.to_s ])
        create(:price, variant: master, currency: currency, amount: 25_000, price_list_id: price_list.id)
      end

      it '旧実装と一致し、price_list の価格(25000)が反映される' do
        with_user(group_user) do
          expect_parity_with_legacy(currency)
          expect(Spree::Product.find(product.id).lowest_price(currency).amount).to eq(25_000)
        end
      end
    end

    context '期間外の scheduled な price_list があるとき' do
      before do
        price_list = create(:price_list, :scheduled, :any_match, store: store)
        create(:customer_group_price_rule, price_list: price_list, customer_group_ids: [ customer_group.id.to_s ])
        create(:price, variant: master, currency: currency, amount: 25_000, price_list_id: price_list.id)
      end

      it '旧実装と一致し、price_list の価格は反映されない' do
        with_user(group_user) do
          expect_parity_with_legacy(currency)
          expect(Spree::Product.find(product.id).lowest_price(currency).amount).to eq(45_815)
        end
      end
    end

    # SQL の照合順序(utf8mb4_general_ci)は大文字小文字を区別しないため、
    # Ruby 側で比較するようになっても同じ価格を拾えること
    context 'DB に保存された通貨が小文字のとき' do
      before { master.prices.where(price_list_id: nil).update_all(currency: currency.downcase) }

      it '旧実装と一致し、定価(45815)を取得できる' do
        expect_parity_with_legacy(currency)
        expect(Spree::Product.find(product.id).lowest_price(currency).amount).to eq(45_815)
      end
    end

    context '店舗の既定通貨と異なる通貨で参照するとき' do
      before do
        create(:price, variant: master, currency: 'USD', amount: 300)
        price_list = create(:price_list, :active, :any_match, store: store)
        create(:customer_group_price_rule, price_list: price_list, customer_group_ids: [ customer_group.id.to_s ])
        create(:price, variant: master, currency: 'USD', amount: 200, price_list_id: price_list.id)
      end

      it 'グループ内ユーザには price_list の価格(200)を返し、旧実装と一致する' do
        with_user(group_user) do
          expect_parity_with_legacy('USD')
          expect(Spree::Product.find(product.id).lowest_price('USD').amount).to eq(200)
        end
      end

      it 'ゲストには定価(300)を返し、旧実装と一致する' do
        with_user(nil) do
          expect_parity_with_legacy('USD')
          expect(Spree::Product.find(product.id).lowest_price('USD').amount).to eq(300)
        end
      end
    end

    describe 'メモ化' do
      subject(:target) { Spree::Product.find(product.id) }

      it 'lowest_price / price_varies? / on_sale? を呼んでも解決は1回だけ' do
        expect(Spree::Pricing::BatchResolver).to receive(:new).once.and_call_original

        target.lowest_price(currency)
        target.price_varies?(currency)
        target.on_sale?(currency)
      end

      it '通貨が変われば解決し直す' do
        expect(Spree::Pricing::BatchResolver).to receive(:new).twice.and_call_original

        target.lowest_price(currency)
        target.lowest_price('USD')
      end
    end

    describe '価格読み込みのクエリ数' do
      let!(:single_variant_product) { create(:product, stores: [ store ]) }
      let!(:many_variants_product) do
        create(:product, stores: [ store ]).tap { |target| 5.times { create(:variant, product: target) } }
      end

      it 'variant 数に関わらず商品ごとに1回で済む' do
        single = count_price_queries { Spree::Product.find(single_variant_product.id).lowest_price(currency) }
        many = count_price_queries { Spree::Product.find(many_variants_product.id).lowest_price(currency) }

        expect([ single, many ]).to eq([ 1, 1 ])
      end
    end
  end
end
