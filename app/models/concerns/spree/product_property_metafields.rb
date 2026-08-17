module Spree
  # Spree 5.4 で Spree::Property が削除されるため、ProductProperty で
  # 保持していた商品の付加情報(gravity_forms / 地図形式 / 提供形態 / short_description 等)を
  # Spree 5.2 の metafields に移行する。その読み書きを一箇所に集約する薄いヘルパー。
  #
  # 移行 rake(migrate_product_properties_to_metafields)は旧 ProductProperty を
  #   namespace="properties", key=property.name, value=product_property.value
  # で metafield にコピー済み。したがって本ヘルパーは namespace="properties" 規約のもとで
  # 本家の get_metafield / set_metafield を薄くラップするだけにとどめ、本家 API を再実装しない。
  #
  # 日本語 key("地図形式" 等)は ba_spree/metafield_definition_decorator.rb が
  # 本家 normalizes(parameterize) を無効化済みのため、そのまま通る(再 normalize 不要)。
  module ProductPropertyMetafields
    extend ActiveSupport::Concern

    PROPERTY_NAMESPACE = 'properties'.freeze

    # 旧 product.property(name) 相当。指定プロパティ名の metafield 値(文字列)を返す。無ければ nil。
    def property_metafield_value(name)
      get_metafield(property_metafield_key(name))&.value
    end

    # 旧 product_properties.create!/update 相当。指定プロパティ名の metafield に値を設定する。
    # MetafieldDefinition は本家 set_metafield 内で find_or_create される。
    def set_property_metafield(name, value)
      set_metafield(property_metafield_key(name), value)
    end

    # 旧 product.has_property? 相当。
    def property_metafield?(name)
      has_metafield?(property_metafield_key(name))
    end

    # PDP 表示用。namespace="properties" かつフロント表示対象(available_on_front_end)の
    # metafield を、定義の作成順で返す。旧
    #   product_properties.joins(:property).merge(Spree::Property.available_on_front_end)
    #     .sort_by_property_position
    # の置き換え。各要素は Spree::Metafield で、name(=表示名) / value / id を持つ。
    def front_end_property_metafields
      public_metafields
        .select { |mf| mf.metafield_definition&.namespace == PROPERTY_NAMESPACE }
        .sort_by { |mf| mf.metafield_definition_id }
    end

    private

    # "提供形態" -> "properties.提供形態"
    def property_metafield_key(name)
      "#{PROPERTY_NAMESPACE}.#{name}"
    end
  end
end
