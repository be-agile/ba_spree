module CurrencyRoundingHelper
  def round_by_currency(amount, currency)
    decimal_places = currency_decimal_places(currency)
    BigDecimal(amount.to_s).round(decimal_places, BigDecimal::ROUND_HALF_UP)
  end

  def currency_decimal_places(currency)
    Money::Currency.find(currency).decimal_places
  end
end
