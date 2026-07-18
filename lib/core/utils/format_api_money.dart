/// Formats API-provided display money amounts.
///
/// Never convert exchange rates in Flutter — use `*_display` fields from the API.
String formatApiMoney(num? amount, String? currency, {String? symbol}) {
  if (amount == null) return '-';

  final code = (currency == null || currency.trim().isEmpty)
      ? 'UGX'
      : currency.trim().toUpperCase();
  final decimals = code == 'AED' ? 2 : 0;
  final formatted = amount.toStringAsFixed(decimals);

  final sym = symbol?.trim();
  if (sym != null && sym.isNotEmpty) {
    return '$formatted $sym';
  }
  return '$formatted $code';
}

/// Prefer display fields; fall back to ledger UGX values when older APIs omit them.
num visibleMoneyAmount({
  num? displayAmount,
  num? ugxAmount,
  String? displayAmountRaw,
  String? ugxAmountRaw,
}) {
  if (displayAmount != null) return displayAmount;
  final fromDisplayRaw = num.tryParse(displayAmountRaw?.toString() ?? '');
  if (fromDisplayRaw != null) return fromDisplayRaw;
  if (ugxAmount != null) return ugxAmount;
  return num.tryParse(ugxAmountRaw?.toString() ?? '') ?? 0;
}

String visibleMoneyCurrency({
  String? displayCurrency,
  String? currency,
}) {
  final d = displayCurrency?.trim();
  if (d != null && d.isNotEmpty) return d.toUpperCase();
  final c = currency?.trim();
  if (c != null && c.isNotEmpty) return c.toUpperCase();
  return 'UGX';
}

/// Convenience for product list/detail cards.
String formatProductPriceLabel({
  num? sellPriceDisplay,
  num? sellPrice,
  String? sellPriceDisplayRaw,
  String? sellPriceRaw,
  String? displayCurrency,
  String? currency,
  String? symbol,
}) {
  final amount = visibleMoneyAmount(
    displayAmount: sellPriceDisplay,
    ugxAmount: sellPrice,
    displayAmountRaw: sellPriceDisplayRaw,
    ugxAmountRaw: sellPriceRaw,
  );
  final code = visibleMoneyCurrency(
    displayCurrency: displayCurrency,
    currency: currency,
  );
  return formatApiMoney(amount, code, symbol: symbol);
}
