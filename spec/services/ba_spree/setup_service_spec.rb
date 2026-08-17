# frozen_string_literal: true

require 'rails_helper'

# ストアを日本仕様に初期設定するサービス。
# 各ショップ固有の情報 (名前・URL・メールアドレス) には触れないことも検証する。
# @see https://github.com/be-agile/giga-repeat/issues/1317
RSpec.describe BaSpree::SetupService, type: :model do
  let!(:japan) { create(:country, iso: 'JP', iso3: 'JPN', name: '日本', iso_name: 'JAPAN', states_required: false) }
  let!(:shipping_category) { create(:shipping_category, name: '既定') }
  let(:store) { create(:store, name: '元のストア名', url: 'original.example.com') }

  describe '.setup' do
    subject { described_class.setup(store: store, load_seed: false) }

    context '国と都道府県' do
      it { expect { subject }.to change { japan.reload.states_required }.from(false).to(true) }
      it { expect { subject }.to change { Spree::State.where(country: japan).count }.by(47) }
      it { subject; expect(Spree::State.find_by(name: '東京都', country: japan)).to be_present }
    end

    context 'ゾーン' do
      let!(:foreign_zone) { Spree::Zone.create!(name: 'EU_VAT', kind: 'country') }

      it { subject; expect(Spree::Zone.find_by(name: '日本')).to be_present }
      it { expect { subject }.to change { Spree::Zone.exists?(foreign_zone.id) }.from(true).to(false) }
      it { subject; expect(Spree::Zone.find_by(name: '日本').countries).to include(japan) }
    end

    context '消費税' do
      before { subject }

      it { expect(Spree::TaxCategory.pluck(:tax_code)).to include('consumption10', 'consumption8', 'consumption0') }
      it { expect(Spree::TaxRate.where(name: '消費税').pluck(:amount)).to contain_exactly(0.1, 0.08, 0) }
      it { expect(Spree::TaxRate.where(name: '消費税')).to all(have_attributes(included_in_price: true, show_rate_in_label: true)) }
    end

    context '配送方法' do
      before { subject }

      let(:shipping_method) { Spree::ShippingMethod.find_by(code: 'fixed') }

      it { expect(shipping_method.attributes).to include('name' => '配送料', 'admin_name' => '配送料(定額)', 'display_on' => 'both') }
      it { expect(shipping_method.calculator.preferred_amount).to eq 500 }
      it { expect(shipping_method.calculator.preferred_currency).to eq 'JPY' }
      it { expect(shipping_method.shipping_categories).to eq [ shipping_category ] }
      it { expect(shipping_method.zones).to include(Spree::Zone.find_by(name: '日本')) }
    end

    context 'ストアの日本向け設定' do
      before { subject }

      it { expect(store.reload.attributes).to include('default_currency' => 'JPY', 'supported_currencies' => 'JPY', 'supported_locales' => 'ja') }
      it { expect(store.reload.default_country).to eq japan }
      it { expect(store.reload.checkout_zone).to eq Spree::Zone.find_by(name: '日本') }
    end

    # ba_spree は「日本仕様にする」までを担い、ショップ固有の情報は呼び出し側の責務とする
    context 'ショップ固有の情報' do
      it { expect { subject }.not_to change { store.reload.name } }
      it { expect { subject }.not_to change { store.reload.url } }
      it { expect { subject }.not_to change { store.reload.mail_from_address } }
    end

    context '2回実行した場合' do
      before { described_class.setup(store: store, load_seed: false) }

      it { expect { subject }.not_to change { Spree::State.where(country: japan).count } }
      it { expect { subject }.not_to change { Spree::TaxRate.where(name: '消費税').count } }
      it { expect { subject }.not_to change { Spree::ShippingMethod.where(code: 'fixed').count } }
      it { expect { subject }.not_to change(Spree::ShippingMethodZone, :count) }
      it { expect { subject }.not_to change(Spree::TaxCategory, :count) }
      # is_default をキーに探すと Spree::TaxCategory#set_default_category が
      # 他を false に落とすため2回目でマッチせず、税区分の無い TaxRate が増えてしまう
      it { expect { subject }.not_to change { Spree::TaxRate.where(tax_category_id: nil).count } }
    end

    context '国マスタが無い場合' do
      before { Spree::State.where(country: japan).delete_all; japan.destroy }

      it { expect { subject }.to raise_error(described_class::CountryNotFoundError, /rails db:seed/) }
    end
  end
end
