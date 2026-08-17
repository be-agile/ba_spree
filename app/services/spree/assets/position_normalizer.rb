module Spree
  module Assets
    # 同一 viewable に属する Spree::Asset の position を、現在の並び順 (position, id) を
    # 保ったまま 1..N の連番へ詰め直す。
    #
    # 管理画面の並び替え (stimulus-sortable) は、移動した 1 件だけに
    # `asset[position] = 画面上のインデックス + 1` を送る。受け側の acts_as_list は
    # 送られた position が既存レコードと衝突したときにしか周囲を詰め直さないため、
    # position が 1..N の連番でないと 200 を返すのに並び順が変わらない。
    # 並び替えの直前と、position が壊れうる経路の直後にこのサービスを呼ぶ。
    #
    # @see https://github.com/be-agile/giga-repeat/issues/1292
    class PositionNormalizer
      # position が 1..N の連番になっていない viewable を検出する条件。
      # 欠番 (最小が 1 でない / 最大が件数と一致しない) と重複 (distinct 数が件数と一致しない) を見る。
      BROKEN_SCOPE_CONDITION = <<~SQL.squish.freeze
        MIN(position) <> 1
        OR MAX(position) <> COUNT(*)
        OR COUNT(DISTINCT position) <> COUNT(*)
      SQL

      class << self
        # @param viewable_type [String]
        # @param viewable_id [Integer]
        # @return [Boolean] 詰め直しを行った場合 true、もともと連番だった場合 false
        def call(viewable_type:, viewable_id:)
          return false if viewable_type.blank? || viewable_id.blank?

          assets = ordered_assets(viewable_type, viewable_id)
          return false if sequential?(assets)

          # 1 件ずつ書き換える途中では position が一時的に重複しうるため、
          # 中断や並行読み取りに晒さないようトランザクションでまとめる。
          Spree::Asset.transaction do
            assets.each_with_index do |asset, index|
              asset.update_column(:position, index + 1) unless asset.position == index + 1
            end
          end
          true
        end

        # position が壊れている viewable の一覧。
        # @return [Array<Array(String, Integer)>] [viewable_type, viewable_id] の配列
        def broken_scopes
          Spree::Asset.unscoped
                      .where.not(viewable_id: nil)
                      .group(:viewable_type, :viewable_id)
                      .having(BROKEN_SCOPE_CONDITION)
                      .pluck(:viewable_type, :viewable_id)
        end

        private

        def ordered_assets(viewable_type, viewable_id)
          Spree::Asset.unscoped
                      .where(viewable_type: viewable_type, viewable_id: viewable_id)
                      .order(:position, :id)
                      .to_a
        end

        def sequential?(assets)
          assets.each_with_index.all? { |asset, index| asset.position == index + 1 }
        end
      end
    end
  end
end
