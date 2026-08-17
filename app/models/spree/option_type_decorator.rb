module Spree
  module OptionTypeDecorator
    # @gem-override spree_core-5.3.6/app/models/spree/option_type.rb#filter_param
    # @see https://github.com/be-agile/giga-repeat/commit/108316dd2cab88a61933080614e15663517c7291
    # Spree 5.3 追従: 本家変更は deprecation 文言のみ。本実装は日本語保持のため独自(name.parameterize を使わない)。
    def filter_param
      # parameterizeを使わず、空白を_に置換し小文字化
      name.to_s.gsub(/\s+/, '_').downcase
    end

    # @gem-override spree_core-5.3.6/app/models/concerns/spree/parameterizable_name.rb#normalize_name
    # @see https://github.com/be-agile/giga-repeat/commit/108316dd2cab88a61933080614e15663517c7291
    def normalize_name
      # 日本語などの非ASCII文字を保持するための修正
      # parameterizeを使わず、空白の除去と小文字化のみを行う
      self.name = name.to_s.strip.downcase
    end
  end
end

# Decoratorを適用
Spree::OptionType.prepend(Spree::OptionTypeDecorator)
