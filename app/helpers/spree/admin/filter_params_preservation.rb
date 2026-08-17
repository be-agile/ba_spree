# frozen_string_literal: true

module Spree
  module Admin
    # 一覧テーブル (spree/admin/tables/_table) の絞り込み条件は、操作するたびに URL から消えてしまう。
    #
    # 1. ツールバーの「検索」「期間」「フィルタービルダー」は独立した GET フォームで、
    #    GET フォームは送信時に action URL のクエリ文字列を捨てて自分の入力だけを付け直すため、
    #    どれか一つを適用すると他のフォームの条件が消える。
    # 2. 並び替え・表示件数のリンクは url_for / query_parameters.slice(:q) で組まれており、
    #    query_state が落ちる (q は残るので結果は絞り込まれたままだが、
    #    フィルターの件数バッジとドロワーが空になり「効いているのに見えないフィルタ」状態になる)。
    #
    # 絞り込み条件を引き継ぐための共通処理をここにまとめる。
    #
    # なおコントローラの TableConcern#process_table_query_state が query_state を params[:q] に
    # マージし直すため、query_state さえ引き継げば ransack のパラメータは再生成される。
    # @see https://github.com/be-agile/giga-repeat/issues/1262
    module FilterParamsPreservation
      # 絞り込み条件ではないため引き継がないパラメータ
      # (page: 条件を変えたら1ページ目に戻すのが自然、commit: 送信ボタンのラベル)
      NON_FILTER_PARAMS = %w[page commit utf8 authenticity_token _method].freeze

      # 現在の URL にある絞り込みパラメータのうち、そのフォーム自身が送信しないものを
      # hidden input として出力する。
      #
      # @param except_q [Array<String, Symbol>] フォーム自身が送信する q[...] のキー
      # @param owns_query_state [Boolean] フィルタービルダーのフォームなら true。
      #   query_state と、そこから生成される q[...] を除外する
      #   (フィルターを削除したときに古い条件が残らないようにするため)
      # @param table [Spree::Admin::Table, nil] owns_query_state が true のときに必要
      # @return [String] hidden input の HTML
      def preserved_filter_params_inputs(except_q: [], owns_query_state: false, table: nil)
        preserved = request.query_parameters.deep_dup
        NON_FILTER_PARAMS.each { |key| preserved.delete(key) }

        excluded_q_keys = except_q.map(&:to_s)
        if owns_query_state
          preserved.delete('query_state')
          excluded_q_keys += query_state_ransack_keys(table)
        end

        if preserved['q'].is_a?(Hash)
          remaining_q = sanitize_ransack_params(preserved['q']).except(*excluded_q_keys)
          remaining_q.present? ? preserved['q'] = remaining_q : preserved.delete('q')
        end

        hidden_inputs_for_params(preserved)
      end

      # ページネーションのリンク用パラメータ。
      # 本家は request.query_parameters をそのまま使うため、OR グループの壊れた ransack キーが
      # そのまま (しかも名前が変質しながら) URL に載り続ける。
      #
      # @param page [Integer] 遷移先のページ
      # @return [Hash]
      def preserved_pagination_params(page)
        preserved = request.query_parameters.deep_dup
        preserved['q'] = preserved_ransack_params if preserved['q'].is_a?(Hash)
        preserved.merge(page: page)
      end

      # URL に載っている ransack のパラメータ (壊れたキーは除く)。
      #
      # コントローラの process_table_query_state が query_state 由来の条件を params[:q] に
      # マージするため、params[:q] を使うと OR グループの grouping が丸ごと展開されてしまう。
      # リンクを組むときは URL 生の q を使う (条件は query_state から再生成される)。
      #
      # @return [Hash]
      def preserved_ransack_params
        sanitize_ransack_params(request.query_parameters['q']) || {}
      end

      private

      # 現在の query_state を引き継ぐための url_for 用パラメータ
      # (値が nil なら url_for が落としてくれる)
      # @return [Hash]
      def preserved_query_state_param
        { query_state: params[:query_state].presence }
      end

      # ransack として意味をなさない壊れたキーを捨てる。
      #
      # フィルタービルダーで「または」グループを使うと、gem の JS が q[g[0][m]] という
      # Rack が正しくパースできない名前の input を生成する:
      #   Rack::Utils.parse_nested_query("q[g[0][m]]=or") #=> {"q"=>{"g[0"=>{"m"=>{"]"=>"or"}}}}
      # これをそのまま引き継ぐと名前が変質したまま増殖していくので捨てる。
      # OR の条件は query_state から正しく再生成されるため、捨てても絞り込み結果は変わらない。
      #
      # @param q_params [Hash, nil]
      # @return [Hash, nil]
      def sanitize_ransack_params(q_params)
        return q_params unless q_params.is_a?(Hash)

        q_params.reject { |key, _value| key.to_s.match?(/[\[\]]/) }
      end

      # 現在の query_state から生成される ransack のキー
      # (コントローラの process_table_query_state と同じ変換を行う)
      # @return [Array<String>]
      def query_state_ransack_keys(table)
        return [] if table.blank? || params[:query_state].blank?

        query_builder = Spree::Admin::Table::QueryBuilder.new(table)
        query_builder.load_from_json(params[:query_state])
        query_builder.to_ransack_params.keys.map(&:to_s)
      end

      # ネストしたパラメータを hidden input に展開する
      # id は付けない (画面上の入力欄と id が重複するのを避けるため)
      def hidden_inputs_for_params(params_hash, prefix = nil)
        safe_join(
          params_hash.map do |key, value|
            name = prefix ? "#{prefix}[#{key}]" : key.to_s

            case value
            when Hash
              hidden_inputs_for_params(value, name)
            when Array
              safe_join(value.map { |item| hidden_field_tag("#{name}[]", item, id: nil) })
            else
              hidden_field_tag(name, value, id: nil)
            end
          end
        )
      end
    end
  end
end
