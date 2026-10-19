require 'rails_helper'

# @see https://github.com/be-agile/giga-repeat/issues/1503
RSpec.describe Spree::Products::Find, type: :model do
  let!(:store) { create(:store, default: true) }
  let!(:taxonomy) { create(:taxonomy, store: store) }

  # A
  # +- B: b1, b2, b3
  # +- C: c1
  #    +- D: d1, d2
  let!(:taxon_a) { create(:taxon, taxonomy: taxonomy, parent: taxonomy.root) }
  let!(:taxon_b) { create(:taxon, taxonomy: taxonomy, parent: taxon_a) }
  let!(:taxon_c) { create(:taxon, taxonomy: taxonomy, parent: taxon_a) }
  let!(:taxon_d) { create(:taxon, taxonomy: taxonomy, parent: taxon_c) }

  let!(:b1) { create(:product, stores: [ store ]) }
  let!(:b2) { create(:product, stores: [ store ]) }
  let!(:b3) { create(:product, stores: [ store ]) }
  let!(:c1) { create(:product, stores: [ store ]) }
  let!(:d1) { create(:product, stores: [ store ]) }
  let!(:d2) { create(:product, stores: [ store ]) }

  before do
    classify(taxon_b, [ b1, b2, b3 ])
    classify(taxon_c, [ c1 ])
    classify(taxon_d, [ d1, d2 ])
  end

  def classify(taxon, products)
    products.each_with_index do |product, index|
      Spree::Classification.create!(product: product, taxon: taxon, position: index + 1)
    end
  end

  describe '#execute' do
    subject { described_class.new(scope: Spree::Product.all, params: params).execute.to_a }

    let(:params) { { store: store, filter: { taxons: taxon.id }, currency: store.default_currency, sort_by: sort_by } }
    let(:taxon) { taxon_a }
    let(:sort_by) { 'manual' }

    it { is_expected.to eq [ b1, b2, b3, c1, d1, d2 ] }

    context "sort_by が 'default' のとき" do
      let(:sort_by) { 'default' }

      it { is_expected.to eq [ b1, b2, b3, c1, d1, d2 ] }
    end

    context 'B の商品の並び順を変えたとき' do
      before { Spree::Classification.find_by!(taxon: taxon_b, product: b3).insert_at(1) }

      it { is_expected.to eq [ b3, b1, b2, c1, d1, d2 ] }
    end

    context 'C を B より前に移したとき' do
      before { taxon_c.move_to_left_of(taxon_b) }

      it { is_expected.to eq [ c1, d1, d2, b1, b2, b3 ] }
    end

    context 'A に直接商品を登録したとき' do
      let!(:a1) { create(:product, stores: [ store ]) }

      before { classify(taxon_a, [ a1 ]) }

      it { is_expected.to eq [ a1, b1, b2, b3, c1, d1, d2 ] }
    end

    context 'b1 を D にも登録したとき' do
      before { Spree::Classification.create!(product: b1, taxon: taxon_d, position: 3) }

      it { is_expected.to eq [ b1, b2, b3, c1, d1, d2 ] }
    end

    context 'C を指定したとき' do
      let(:taxon) { taxon_c }

      it { is_expected.to eq [ c1, d1, d2 ] }
    end

    context '子カテゴリを持たない B を指定したとき' do
      let(:taxon) { taxon_b }

      before { Spree::Classification.find_by!(taxon: taxon_b, product: b3).insert_at(1) }

      it { is_expected.to eq [ b3, b1, b2 ] }
    end

    context "sort_by が 'name-z-a' のとき" do
      let(:sort_by) { 'name-z-a' }

      it { is_expected.to eq [ b1, b2, b3, c1, d1, d2 ].sort_by(&:name).reverse }
    end
  end
end
