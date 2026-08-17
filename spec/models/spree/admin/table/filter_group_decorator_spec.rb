# frozen_string_literal: true

require 'rails_helper'

# フィルタービルダーの「または」グループが ransack に届かず、絞り込みとして機能していなかった (#1262)。
# 本家は p (述語) と v (値) を a (属性) の内側に入れており、ransack が grouping ごと黙って無視するため
# 全件が返ってしまう。また述語を sub('_', '') で作るため not_eq が "noteq" に化ける。
RSpec.describe Spree::Admin::Table::FilterGroup, type: :model do
  describe '#to_ransack_params' do
    subject(:ransack_params) { root_group.to_ransack_params }

    let(:root_group) { described_class.new(combinator: :and) }
    let(:or_group) { described_class.new(combinator: :or) }

    before do
      root_group.add_group(or_group)
      or_group.add_filter(
        Spree::Admin::Table::Filter.new(field: 'bill_address_lastname', operator: :cont, value: '岡')
      )
      or_group.add_filter(
        Spree::Admin::Table::Filter.new(field: 'bill_address_lastname', operator: :not_eq, value: '渡辺')
      )
    end

    it 'p (述語) と v (値) を a (属性) の兄弟として組み立てること' do
      condition = ransack_params.dig(:g, '0', :c, '0')

      expect(condition).to eq(
        a: { '0' => { name: 'bill_address_lastname' } },
        p: 'cont',
        v: { '0' => { value: '岡' } }
      )
    end

    it '述語の _ を落とさないこと (not_eq が noteq にならない)' do
      expect(ransack_params.dig(:g, '0', :c, '1', :p)).to eq('not_eq')
    end

    it 'OR の結合子を渡すこと' do
      expect(ransack_params.dig(:g, '0', :m)).to eq('or')
    end

    # 生成した params が実際に ransack で OR 条件になることを SQL で確認する (レコードは不要)
    it 'ransack が OR 条件として解釈すること' do
      sql = Spree::Order.ransack(ransack_params).result.to_sql

      expect(sql).to include('OR')
      expect(sql).to include('岡')
      expect(sql).to include('渡辺')
    end

    # in / not_in は配列を値に取る。値をまとめて1つの v に入れると ransack がマッチせず 0件になる
    context '値が配列の述語 (次のいずれか / in) の場合' do
      let(:or_group) { described_class.new(combinator: :or) }

      before do
        or_group.filters.clear
        or_group.add_filter(
          Spree::Admin::Table::Filter.new(field: 'payment_state', operator: :in, value: %w[paid failed])
        )
      end

      it '配列の要素ごとに v のエントリを作ること' do
        expect(ransack_params.dig(:g, '0', :c, '0', :v)).to eq(
          '0' => { value: 'paid' },
          '1' => { value: 'failed' }
        )
      end

      it 'ransack が IN 条件として解釈すること (0件にならない)' do
        sql = Spree::Order.ransack(ransack_params).result.to_sql

        expect(sql).to include('paid')
        expect(sql).to include('failed')
      end
    end

    context '値が未入力の場合' do
      let(:or_group) { described_class.new(combinator: :or) }

      before do
        or_group.filters.clear
        or_group.add_filter(
          Spree::Admin::Table::Filter.new(field: 'payment_state', operator: :in, value: [])
        )
      end

      it '空の v を作らないこと (ransack がその条件を無視できるようにする)' do
        expect(ransack_params.dig(:g, '0', :c, '0', :v)).to eq('0' => { value: nil })
      end
    end
  end
end
