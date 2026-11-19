/// Rounds a price to whole francs and adds thousands separators: 1234.6 -> "1,235".
String formatPrice(double price) {
  final digits = price.round().toString();
  return digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

const _monthAbbreviations = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', //
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

/// The month tag on the result ticket, e.g. (2026, 6) -> "JUN 2026".
String monthTag(int year, int month) => '${_monthAbbreviations[month - 1]} $year';
