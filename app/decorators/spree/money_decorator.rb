module Spree
  module MoneyDecorator
    # Fix amount_in_cents for JPY and other zero-decimal currencies
    # Money gem already returns the correct value in the smallest unit,
    # so we don't need the × 100 conversion that breaks JPY
    # @gem-override spree_core-5.3.6/lib/spree/money.rb#amount_in_cents
    # reason: JPY 等のゼロ小数通貨では Money gem が既に最小単位を返すため、本家の ×100 変換が壊れる。
    #   cents をそのまま返すよう super なしで再実装 (Issue #1004)
    # @see https://github.com/be-agile/giga-repeat/issues/1004
    def amount_in_cents
      cents
    end

    # @gem-override spree_core-5.3.6/lib/spree/money.rb#to_html
    # reason: JPY の負の金額で符号位置が崩れる問題への対処。本家整形後に符号を金額の前へ移す (Issue #292)
    # @see https://github.com/be-agile/giga-repeat/issues/292
    def to_html(opts = { html: true })
      opts[:html_wrap] = opts[:html]
      opts.delete(:html)
      output = money.format(options.merge(opts))

      if opts[:html_wrap]
        output.gsub!(/<\/?[^>]*>/, '')
        output = output.sub(' ', '&nbsp;').html_safe
      end

      if money.currency.iso_code == "JPY" && money.cents.negative?
        output.gsub!(/-/, '')
        output.gsub!(/([\D]*)(\d[\d,\.]*)/, '-\2\1')
      end

      output
    end

    # @gem-override spree_core-5.3.6/lib/spree/money.rb#to_s
    # reason: JPY の負の金額で符号位置が崩れる問題への対処。本家整形後に符号を金額の前へ移す (Issue #292)
    # @see https://github.com/be-agile/giga-repeat/issues/292
    def to_s
      output = money&.format(options)

      if output.present? && money.currency.iso_code == "JPY" && money.cents.negative?
        output.gsub!(/-/, '')
        output.gsub!(/([\D]*)(\d[\d,\.]*)/, '-\2\1')
      end

      output
    end
  end
end

Spree::Money.prepend(Spree::MoneyDecorator)
