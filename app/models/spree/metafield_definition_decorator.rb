module Spree
  # @gem-override spree_core-5.3.6/app/models/spree/metafield_definition.rb
  # reason: 本家 MetafieldDefinition は key/namespace に
  #   `normalizes :key, with: ->(v){ v.parameterize.underscore.strip }` を掛けており、
  #   parameterize が非ASCII(日本語)を除去するため、日本語のプロパティ名(「地図形式」「提供形態」等)を
  #   key にすると空文字になり、key 必須・name 必須(set_name_from_key も空)でバリデーションに失敗する。
  #   ba_spree は既に Property / OptionType / OptionValue / FilterParam で
  #   「parameterize を使わず日本語を保持する」方針を採用済み(ba_spree の各 *_decorator 参照)。
  #   MetafieldDefinition も同方針に揃え、Spree 5.2 の product properties → metafields 移行で
  #   日本語のプロパティ名をそのまま key/name として保持できるようにする。
  #
  # 実装メモ:
  #   本家の normalizes は decorate_attributes で属性の型を NormalizedValueType でラップし、
  #   before_validation(:normalize_changed_in_place_attributes) でも再正規化する。
  #   後から normalizes を再宣言しても元の parameterize が累積して残るため、
  #   いったん `attribute` で型をリセットしてラップを外し、normalized_attributes からも除外したうえで、
  #   parameterize を使わない自前の正規化(前後空白の除去のみ)を宣言し直す。
  module MetafieldDefinitionDecorator
    extend ActiveSupport::Concern

    included do
      # 本家 normalizes(parameterize)のラップを外す
      attribute :key, :string
      attribute :namespace, :string
      self.normalized_attributes -= [ :key, :namespace ]

      # parameterize せず、前後空白の除去のみ(日本語を保持)
      normalizes :key, with: ->(value) { value.to_s.strip }
      normalizes :namespace, with: ->(value) { value.to_s.strip }
    end
  end
end

Spree::MetafieldDefinition.include(Spree::MetafieldDefinitionDecorator)
