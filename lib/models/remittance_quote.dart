// Fixed fictional numbers for the preview, not a live exchange rate or fee.
class RemittanceQuote {
  static const sampleFeeCentavos = 5000; // PHP 50.00, added to the amount.
  static const sampleRateLabel = '1 PHP = K 0.0700';
  final int principalCentavos;
  RemittanceQuote(this.principalCentavos) {
    if (principalCentavos <= 0 || principalCentavos > 10000000) {
      throw ArgumentError('Use PHP 0.01–100,000.00 in this preview.');
    }
  }
  int get totalCentavos => principalCentavos + sampleFeeCentavos;
  // 7 toea per peso; round to the nearest toea using integer arithmetic.
  int get recipientToea => (principalCentavos * 7 + 50) ~/ 100;
  static int? parseCentavos(String text) {
    final clean = text.trim();
    if (!RegExp(r'^\d{1,6}(\.\d{1,2})?$').hasMatch(clean)) return null;
    final parts = clean.split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
  }

  static String php(int amount) => 'PHP ${(amount / 100).toStringAsFixed(2)}';
  static String kina(int amount) => 'K ${(amount / 100).toStringAsFixed(2)}';
}
