require 'rails_helper'

# storefront API の商品取得を HTML 側と同じ公開状態の判定に揃える（#1352）。
# 本家は scope が for_store + accessible_by(:show) だけで、ゲストに `can :read, Spree::Product`
# が条件なしで与えられるため、非公開・取扱対象外・論理削除済みの商品まで返っていた。
RSpec.describe 'Storefront API product visibility', type: :request do
  let!(:store) { create(:store, default: true, url: 'test.localhost') }
  let!(:active_product) { create(:product, stores: [ store ], status: 'active') }
  let!(:draft_product) { create(:product, stores: [ store ], status: 'draft') }
  let!(:archived_product) { create(:product, stores: [ store ], status: 'archived') }
  let!(:deleted_product) { create(:product, stores: [ store ], status: 'active').tap(&:destroy) }

  before do
    host! 'test.localhost'
    Rails.cache.delete('default_store')
  end

  def json_ids
    JSON.parse(response.body)['data'].map { |row| row['id'].to_i }
  end

  describe 'GET /api/v2/storefront/products' do
    it '公開中の商品だけを返す' do
      get '/api/v2/storefront/products'

      expect(json_ids).to include(active_product.id)
      expect(json_ids).not_to include(draft_product.id, archived_product.id, deleted_product.id)
    end

    # filter[show_discontinued] / filter[show_deleted] は Spree::Products::Find が
    # 公開状態・論理削除のフィルタを外すためのパラメータ。これで迂回できないことを担保する。
    it 'show_discontinued を渡しても非公開・取扱対象外を返さない' do
      get '/api/v2/storefront/products', params: { filter: { show_discontinued: true } }

      expect(json_ids).not_to include(draft_product.id, archived_product.id)
    end

    it 'show_deleted を渡しても論理削除済みを返さない' do
      get '/api/v2/storefront/products', params: { filter: { show_deleted: true } }

      expect(json_ids).not_to include(deleted_product.id)
    end
  end

  describe 'GET /api/v2/storefront/products/:id' do
    it '公開中の商品は 200' do
      get "/api/v2/storefront/products/#{active_product.slug}"

      expect(response).to have_http_status(:ok)
    end

    it '非公開（draft）は 404' do
      get "/api/v2/storefront/products/#{draft_product.slug}"

      expect(response).to have_http_status(:not_found)
    end

    it '取扱対象外（archived）は 404' do
      get "/api/v2/storefront/products/#{archived_product.slug}"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v2/storefront/products/:id/variants' do
    it '公開中の商品は 200' do
      get "/api/v2/storefront/products/#{active_product.slug}/variants"

      expect(response).to have_http_status(:ok)
    end

    it '非公開（draft）は 404' do
      get "/api/v2/storefront/products/#{draft_product.slug}/variants"

      expect(response).to have_http_status(:not_found)
    end

    it '取扱対象外（archived）は 404' do
      get "/api/v2/storefront/products/#{archived_product.slug}/variants"

      expect(response).to have_http_status(:not_found)
    end
  end
end
