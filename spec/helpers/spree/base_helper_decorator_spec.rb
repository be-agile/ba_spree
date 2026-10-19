require 'rails_helper'

# Issue #1153: フラグメントキャッシュのキーにユーザごとの差が入っていないと、
# カテゴリ・商品・価格をユーザごとに絞ったときに別ユーザ向けの HTML がそのまま出る。
# @see https://github.com/be-agile/giga-repeat/issues/1153
RSpec.describe Spree::BaseHelper, type: :helper do
  let!(:store) { create(:store, default: true) }
  let!(:group_a) { create(:customer_group, store: store) }
  let!(:group_b) { create(:customer_group, store: store) }
  let(:user) { create(:user) }

  describe '#spree_base_cache_key' do
    subject { helper.spree_base_cache_key }

    # Spree::BaseHelper 自身は try_spree_current_user を持たない(コントローラ側の
    # ヘルパーメソッド)ため、本家の defined? ガードごと再現できるよう特異メソッドで生やす
    before do
      signed_in_user = current_user
      helper.define_singleton_method(:try_spree_current_user) { signed_in_user }
    end

    context '顧客グループに所属しているユーザ' do
      let(:current_user) { user }

      before do
        create(:customer_group_user, customer_group: group_b, user: user)
        create(:customer_group_user, customer_group: group_a, user: user)
      end

      it { is_expected.to include([ group_a.id, group_b.id ].sort) }
    end

    context 'どの顧客グループにも所属していないユーザ' do
      let(:current_user) { user }

      it { is_expected.to include([]) }
      it { is_expected.not_to include([ group_a.id, group_b.id ].sort) }
    end

    context '未ログイン' do
      let(:current_user) { nil }

      it { is_expected.not_to include([]) }
    end
  end
end
