# frozen_string_literal: true

require 'rails_helper'

# 一覧テーブルのツールバーは「検索」「期間」「フィルタービルダー」が独立した GET フォームになっており、
# どれか一つを適用すると他のフォームの絞り込み条件が URL から消えてしまう (#1262)。
# 各フォームに「自分が送信しないパラメータ」を hidden input として持たせて併用できるようにする。
RSpec.describe Spree::Admin::FilterParamsPreservation, type: :helper do
  let(:table) { Spree.admin.tables.get(:orders) }

  # フィルタービルダーで「品番[SKU] を含む 01-570」を1件指定した状態
  let(:sku_query_state) do
    {
      id: 'root',
      combinator: 'and',
      filters: [ { id: 'f1', field: 'line_items_variant_sku', operator: 'cont', value: '01-570' } ],
      groups: []
    }.to_json
  end

  let(:query_parameters) { {} }

  before do
    allow(helper).to receive_messages(
      request: instance_double(ActionDispatch::Request, query_parameters: query_parameters),
      params: ActionController::Parameters.new(query_parameters)
    )
  end

  # 生成された hidden input を { name => value } で返す
  def hidden_inputs(html)
    Nokogiri::HTML.fragment(html).css('input').to_h { |input| [ input['name'], input['value'] ] }
  end

  describe '#preserved_filter_params_inputs' do
    context '期間で絞り込んでいる状態で、検索フォームに差し込む場合' do
      let(:query_parameters) do
        {
          'q' => {
            'multi_search' => 'テスト',
            'completed_at_gt' => '2009-10-01',
            'completed_at_lt' => '2009-10-15'
          }
        }
      end

      it '検索フォーム自身が送信する q[multi_search] は出力せず、期間は引き継ぐこと' do
        inputs = hidden_inputs(helper.preserved_filter_params_inputs(except_q: [ :multi_search ]))

        expect(inputs).to eq(
          'q[completed_at_gt]' => '2009-10-01',
          'q[completed_at_lt]' => '2009-10-15'
        )
      end
    end

    context '期間フォームに差し込む場合' do
      let(:query_parameters) do
        {
          'q' => {
            'multi_search' => 'テスト',
            'completed_at_gt' => '2009-10-01',
            'completed_at_lt' => '2009-10-15',
            'line_items_variant_sku_cont' => '01-570'
          },
          'query_state' => sku_query_state
        }
      end

      it '期間フォーム自身が送信する q は出力せず、検索とフィルターを引き継ぐこと' do
        inputs = hidden_inputs(
          helper.preserved_filter_params_inputs(except_q: %w[completed_at_gt completed_at_lt])
        )

        expect(inputs).to eq(
          'q[multi_search]' => 'テスト',
          'q[line_items_variant_sku_cont]' => '01-570',
          'query_state' => sku_query_state
        )
      end
    end

    context 'フィルタービルダーのフォームに差し込む場合 (owns_query_state)' do
      let(:query_parameters) do
        {
          'q' => {
            'completed_at_gt' => '2009-10-01',
            'line_items_variant_sku_cont' => '01-570'
          },
          'query_state' => sku_query_state
        }
      end

      # フィルターを削除したときに古い条件が hidden で残り続けないようにするため、
      # query_state と、そこから生成される q[...] は引き継がない (JS が生成し直す)
      it 'query_state と、そこから生成される q は出力せず、期間だけ引き継ぐこと' do
        inputs = hidden_inputs(
          helper.preserved_filter_params_inputs(owns_query_state: true, table: table)
        )

        expect(inputs).to eq('q[completed_at_gt]' => '2009-10-01')
      end
    end

    context '配列のパラメータがある場合' do
      # サイドバーの「履行すべき注文」が使う形
      let(:query_parameters) do
        { 'q' => { 'shipment_state_not_in' => %w[shipped canceled] } }
      end

      it '[] 付きの name で展開すること' do
        html = helper.preserved_filter_params_inputs
        names = Nokogiri::HTML.fragment(html).css('input').map { |input| input['name'] }
        values = Nokogiri::HTML.fragment(html).css('input').map { |input| input['value'] }

        expect(names).to eq([ 'q[shipment_state_not_in][]', 'q[shipment_state_not_in][]' ])
        expect(values).to eq(%w[shipped canceled])
      end
    end

    context '絞り込み条件ではないパラメータがある場合' do
      let(:query_parameters) do
        {
          'q' => { 'completed_at_gt' => '2009-10-01' },
          'page' => '3',
          'commit' => 'フィルターを適用する',
          'per_page' => '50'
        }
      end

      it 'page と commit は引き継がず、per_page (表示件数) は引き継ぐこと' do
        inputs = hidden_inputs(helper.preserved_filter_params_inputs)

        expect(inputs).to eq(
          'q[completed_at_gt]' => '2009-10-01',
          'per_page' => '50'
        )
      end
    end

    # フィルタービルダーで「または」グループを使うと、gem の JS が q[g[0][m]] という
    # Rack が正しくパースできない名前を生成し、q に壊れたキー "g[0" が入る。
    # 引き継ぐと名前が変質したまま増殖するため捨てる (OR の条件は query_state から再生成される)。
    context 'OR グループによる壊れた ransack キーがある場合' do
      let(:or_query_parameters) do
        Rack::Utils.parse_nested_query(
          'q[g[0][m]]=or&q[g[0][c][0][email_cont]]=example.com&q[completed_at_gt]=2009-10-01'
        )
      end
      let(:query_parameters) { or_query_parameters }

      it '壊れたキーは引き継がず、正常なキーだけ引き継ぐこと' do
        inputs = hidden_inputs(helper.preserved_filter_params_inputs)

        expect(inputs).to eq('q[completed_at_gt]' => '2009-10-01')
      end
    end

    context '引き継ぐパラメータが無い場合' do
      let(:query_parameters) { { 'q' => { 'multi_search' => 'テスト' } } }

      it '空文字を返すこと (空の q[] を出力しないこと)' do
        expect(helper.preserved_filter_params_inputs(except_q: [ :multi_search ])).to eq('')
      end
    end
  end

  # 並び替え・表示件数のリンクは URL 生の q を使う。
  # params[:q] はコントローラが query_state 由来の条件をマージした後の値で、
  # OR グループの grouping が丸ごと展開されてリンクが肥大するため。
  describe '#preserved_ransack_params' do
    let(:query_parameters) do
      Rack::Utils.parse_nested_query(
        'q[completed_at_gt]=2009-10-01&q[g[0][m]]=or&q[g[0][c][0][email_cont]]=example.com'
      )
    end

    it '壊れたキーを除いた q を返すこと' do
      expect(helper.preserved_ransack_params).to eq('completed_at_gt' => '2009-10-01')
    end

    context 'q が無い場合' do
      let(:query_parameters) { {} }

      it '空の Hash を返すこと' do
        expect(helper.preserved_ransack_params).to eq({})
      end
    end
  end

  describe '#preserved_pagination_params' do
    let(:query_parameters) do
      Rack::Utils.parse_nested_query(
        'q[completed_at_gt]=2009-10-01&q[g[0][m]]=or&query_state=%7B%7D&per_page=50&page=3'
      )
    end

    it '壊れたキーを除き、query_state と表示件数を引き継いで page を差し替えること' do
      expect(helper.preserved_pagination_params(2)).to eq(
        'q' => { 'completed_at_gt' => '2009-10-01' },
        'query_state' => '{}',
        'per_page' => '50',
        'page' => '3',
        page: 2
      )
    end
  end
end
