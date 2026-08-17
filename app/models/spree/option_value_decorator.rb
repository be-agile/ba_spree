module Spree
  module OptionValueDecorator
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
Spree::OptionValue.prepend(Spree::OptionValueDecorator)
