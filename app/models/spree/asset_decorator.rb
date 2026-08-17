module Spree
  # @gem-override spree_core-5.3.6/app/models/spree/asset.rb
  # reason: Spree 5.3 で Asset#attachment に named variant の事前生成ブロック
  #   (mini/small/medium/large/xlarge/og_image を format: webp + preprocessed: true で定義)が
  #   追加された。preprocessed: true は画像 attach 時に 1 画像あたり 6 本の
  #   ActiveStorage::TransformJob をキューし、さらに表示時に未生成 variant を
  #   /rails/active_storage/representations/... でオンザフライ webp 変換する。
  #
  #   動産社等のローカル / stg では画像 blob の実体が本番 S3 にしか無く、変換が
  #   元画像を取得できずに 1 リクエストあたり数百ms〜1秒の遅延・失敗となる。画像の多い
  #   ページではこれが積み重なり、スモークテスト / ブラウザテストがタイムアウトする
  #   (Issue #1210 のコメント参照)。
  #
  #   そこで「variant の定義自体は残す(ビューの image.variant(:large) 等が
  #   ArgumentError にならないように)が、事前生成 preprocessed を環境フラグで
  #   false に倒す」ことで、attach 時の TransformJob 大量発行を止める。
  #   本番(フラグ未設定)では 5.3 デフォルトの preprocessed: true を維持する。
  #
  # 制御: ENV['DISABLE_IMAGE_VARIANT_PREPROCESSING'] が truthy のとき preprocessed を無効化。
  #   development / test ではデフォルトで無効化する(画像実体が無い環境での遅延回避)。
  #
  # ⚠️ stg は RAILS_ENV=production で動作するため、env 名だけでは本番と区別できない。
  #   stg で画像処理を止めたい場合は stg のデプロイ環境変数に
  #   DISABLE_IMAGE_VARIANT_PREPROCESSING=true を明示設定すること。
  #   本番環境では未設定のままにし、5.3 デフォルト(preprocessed: true)を維持する。
  #
  # @see https://github.com/be-agile/giga-repeat/issues/1210
  module AssetDecorator
    def self.prepended(base)
      # acts_as_list の採番 (bottom_position_in_list + 1) はロックを取らないため、
      # 管理画面の一括アップロードのように同一 viewable へ並列に INSERT すると
      # 同じ position を持つレコードが同時に作られる。その状態になると並び替えが
      # 効かなくなるため、採番より先に viewable の行を排他ロックして直列化する。
      # acts_as_list の before_create :avoid_collision より先に走らせる必要がある。
      # @see https://github.com/be-agile/giga-repeat/issues/1292
      base.before_create :lock_position_scope, prepend: true

      base.has_one_attached :attachment, service: Spree.public_storage_service_name do |attachable|
        # 本家同様、キー順(format, resize_to_fill, saver)を維持して variation digest を一致させる。
        Spree::Config.product_image_variant_sizes.each do |name, (width, height)|
          attachable.variant name,
                              format: 'webp',
                              resize_to_fill: [ width, height ],
                              saver: Spree::Asset::WEBP_SAVER_OPTIONS,
                              preprocessed: !Spree::Asset.image_variant_preprocessing_disabled?
        end
      end
    end

    # viewable の行に排他ロックを取ったうえで position を採番し、同一 viewable への
    # 並列 INSERT を直列化する。ロックはこの save のトランザクション終了時に解放される。
    #
    # 採番をここで行うのは、acts_as_list の採番が通常の SELECT (consistent read) で
    # 最大 position を読むためである。MySQL の REPEATABLE READ では、行ロックの取得を
    # 待っている間に他トランザクションが commit した行が consistent read から見えず、
    # ロックを取っても同じ position を採番してしまう。ロック付き読み取り (FOR UPDATE) は
    # 常に最新の確定値を読むため、こちらで採番する。
    #
    # viewable が未確定 (新規商品作成時のセッション退避アップロード等) の場合は
    # ロック対象の行が無いため何もしない。この経路の position は
    # Spree::Admin::ProductsControllerDecorator が付け替え後に詰め直す。
    def lock_position_scope
      return if viewable_id.blank? || viewable_type.blank?

      lock_viewable_row
      return if self[:position].present?

      bottom = Spree::Asset.unscoped
                           .where(viewable_type: viewable_type, viewable_id: viewable_id)
                           .lock
                           .maximum(:position)
      self[:position] = bottom.to_i + 1
    end

    # 同一 viewable の position を操作する処理を直列化するための行ロック。
    # 採番(lock_position_scope)と並び替え(Spree::Admin::AssetsControllerDecorator)の
    # 双方が同じ行を取り合うことで、両者が混ざらないようにする。
    def lock_viewable_row
      return if viewable_id.blank? || viewable_type.blank?

      viewable_class = viewable_type.safe_constantize
      return if viewable_class.nil?

      viewable_class.unscoped.lock.where(id: viewable_id).pick(:id)
    end

    module ClassMethods
      # 画像 variant の事前生成(preprocessed)を無効化すべき環境かどうか。
      # ENV['DISABLE_IMAGE_VARIANT_PREPROCESSING'] を最優先で見る(本番でも明示的に切り替え可能)。
      # 未設定なら development / test で自動的に無効化する。
      def image_variant_preprocessing_disabled?
        flag = ENV['DISABLE_IMAGE_VARIANT_PREPROCESSING']
        return ActiveModel::Type::Boolean.new.cast(flag) unless flag.nil?

        Rails.env.development? || Rails.env.test?
      end
    end
  end
end

Spree::Asset.singleton_class.prepend(Spree::AssetDecorator::ClassMethods)
Spree::Asset.prepend(Spree::AssetDecorator)
