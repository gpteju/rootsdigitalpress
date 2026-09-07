// CHANGE-2026-09-07: Created formatting utilities for currency, dates, and number representations.

import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
    locale: 'en_IN',
  );

  static final DateFormat _dateFormat = DateFormat('dd-MMM-yyyy');
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');

  /// Formats numeric value as Indian Rupee (₹1,250.00)
  static String formatCurrency(dynamic value) {
    if (value == null) return '₹0.00';
    final double numVal = double.tryParse(value.toString()) ?? 0.0;
    return _currencyFormat.format(numVal);
  }

  /// Formats Date into "07-Sep-2026" display format
  static String formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      final DateTime dt = DateTime.parse(dateStr.toString());
      return _dateFormat.format(dt);
    } catch (_) {
      return dateStr.toString();
    }
  }

  /// Converts DateTime to ISO Date String "2026-09-07" for API requests
  static String toIsoDate(DateTime dt) {
    return _isoDateFormat.format(dt);
  }

  /// Formats quantity with 2 decimal places
  static String formatQty(dynamic qty) {
    if (qty == null) return '0.00';
    final double numVal = double.tryParse(qty.toString()) ?? 0.0;
    return numVal.toStringAsFixed(2);
  }
}
