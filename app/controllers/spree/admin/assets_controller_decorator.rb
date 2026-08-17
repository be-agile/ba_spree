module Spree
  module Admin
    module AssetsControllerDecorator
      # @gem-override spree_admin-5.3.6/app/controllers/spree/admin/assets_controller.rb#update
      # @see https://github.com/be-agile/giga-repeat/issues/1292
      #
      # 並び替え (stimulus-sortable) は移動した 1 件だけに asset[position] を送るが、
      # その値は DB の position ではなく「画面上のインデックス + 1」である。
      # acts_as_list は送られた position が既存レコードと衝突したときしか周囲を
      # 詰め直さないため、position が 1..N の連番でないと 200 を返すのに並び順が
      # 変わらない。並び替えのときだけ、先に連番へ詰め直してから本家の更新に渡す。
      #
      # 詰め直しと本家の更新は 1 つのトランザクションに入れ、採番(Spree::AssetDecorator)と
      # 同じ viewable 行ロックを取る。そうしないと、詰め直してから更新するまでの間に
      # アップロードが 1 件 INSERT され、本家が前提にしている「1..N の連番」が崩れる。
      # ロックを保持したままレスポンスを描画することになるが、並び替えの応答は
      # JSON 1 件か小さな turbo_stream なので影響は小さい。
      def update
        return super unless sorting_request?

        Spree::Asset.transaction do
          @asset.lock_viewable_row
          normalize_positions
          super
        end
      end

      private

      # 画像編集ダイアログからの更新 (alt / attachment) は position を送らない。
      def sorting_request?
        params.dig(:asset, :position).present?
      end

      def normalize_positions
        normalized = Spree::Assets::PositionNormalizer.call(
          viewable_type: @asset.viewable_type,
          viewable_id: @asset.viewable_id
        )
        # 詰め直しは update_column で行うため、メモリ上の @asset に反映されていない。
        # 古い position のまま保存すると acts_as_list が詰め直す範囲を誤る。
        @asset.reload if normalized
      end
    end
  end
end

Spree::Admin::AssetsController.prepend(Spree::Admin::AssetsControllerDecorator)
