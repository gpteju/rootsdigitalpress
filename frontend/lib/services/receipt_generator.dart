// CHANGE-2026-09-08: NeuGen-aligned ReceiptGenerator for 3-inch (80mm) thermal receipts.
// Emits the exact line-tag protocol used by NeuGen POS for pixel-perfect thermal raster printing:
//   DBC: -> Double-size Bold Centered (Company Name, Receipt Title)
//   CB:  -> Centered Bold (Address, GSTIN, Phone, Sub-header)
//   C:   -> Centered Normal (Tagline, Thank you)
//   DB:  -> Double-size Bold Left
//   B:   -> Left-aligned Bold (Detail labels, headers)
//   L:   -> Left-aligned Normal / Two-column rows
//   BC:  -> Bold Two-column Row (GRAND TOTAL)
//   D:   -> Full-width Divider Line

import 'printer_service.dart';

class ReceiptGenerator {
  /// 80 mm / 3-inch thermal paper at standard font = 47 characters per line.
  static const int width = 47;

  // Item column character widths (Sum = 47)
  static const int _nameWidth = 27;
  static const int _qtyWidth = 6;
  static const int _priceWidth = 14;

  // ── Word Wrapping & Low-level formatting helpers ──────────────────────────

  static List<String> wordWrap(String text, int maxWidth) {
    if (text.trim().isEmpty) return [];
    final List<String> lines = [];
    final words = text.split(RegExp(r'\s+'));
    String currentLine = '';
    for (final word in words) {
      if (currentLine.isEmpty) {
        currentLine = word;
      } else if (currentLine.length + 1 + word.length <= maxWidth) {
        currentLine += ' $word';
      } else {
        lines.add(currentLine);
        currentLine = word;
      }
    }
    if (currentLine.isNotEmpty) lines.add(currentLine);
    return lines;
  }

  static String _centerRaw(String text) {
    if (text.length >= width) return text.substring(0, width);
    final padding = (width - text.length) ~/ 2;
    return ' ' * padding + text;
  }

  // ── Tagged line constructors ─────────────────────────────────────────────

  static String center(String text) => 'C:${_centerRaw(text)}';
  static String centerBold(String text) => 'CB:${_centerRaw(text)}';
  static String centerAddress(String text) => 'CA:${_centerRaw(text)}';
  static String doubleBoldCenter(String text) => 'DBC:${_centerRaw(text)}';
  static String boldLeft(String text) => 'B:$text';
  static String divider([String char = '-']) => 'D:${char * width}';

  /// Two-column row (label ... value). Never exceeds [width].
  static String formatRowTwo(String label, String value) {
    if (value.length >= width) return 'L:${value.substring(0, width)}';
    final available = width - value.length;
    if (label.length > available) {
      final maxLen = (available - 1).clamp(0, available);
      label = maxLen > 3 ? '${label.substring(0, maxLen - 3)}...' : label.substring(0, maxLen);
    }
    final spaces = width - label.length - value.length;
    return 'L:${label + ' ' * (spaces > 0 ? spaces : 1) + value}';
  }

  /// Bold two-column row (used for GRAND TOTAL)
  static String formatRowTwoBold(String label, String value) {
    final row = formatRowTwo(label, value);
    return 'BC:${row.substring(2)}';
  }

  /// Three-column item row: ITEM NAME | QTY | AMOUNT
  static String formatRowThree(String name, String qty, String price) {
    const maxNameLen = _nameWidth - 1;
    if (name.length > maxNameLen) {
      final cut = (maxNameLen - 3).clamp(0, maxNameLen);
      name = '${name.substring(0, cut)}...';
    }
    return 'L:${name.padRight(_nameWidth)}${qty.padLeft(_qtyWidth)}${price.padLeft(_priceWidth)}';
  }

  /// Formats a three-column item row, wrapping long item descriptions across lines
  /// so that no part of the item description is truncated.
  static List<String> formatRowThreeLines(String name, String qty, String price) {
    const maxNameLen = _nameWidth - 1;
    if (name.length <= maxNameLen) {
      return [formatRowThree(name, qty, price)];
    }

    final words = name.split(' ');
    final lines = <String>[];
    String current = '';
    for (final word in words) {
      final candidate = current.isEmpty ? word : '$current $word';
      if (candidate.length > maxNameLen) {
        if (current.isNotEmpty) {
          lines.add(current);
          current = word;
        } else {
          lines.add(word.substring(0, maxNameLen));
          current = word.substring(maxNameLen);
        }
      } else {
        current = candidate;
      }
    }
    if (current.isNotEmpty) lines.add(current);

    final result = <String>[];
    for (int i = 0; i < lines.length - 1; i++) {
      result.add('L:${lines[i].padRight(width)}');
    }
    result.add(formatRowThree(lines.last, qty, price));
    return result;
  }

  // ── Receipt Generators ───────────────────────────────────────────────────

  /// Generates complete tagged receipt text from ReceiptPrintData
  static String generateReceipt(ReceiptPrintData data) {
    final buffer = StringBuffer();

    // 1. Header: Company details
    buffer.writeln(doubleBoldCenter(data.companyName.toUpperCase()));

    if (data.companyAddress != null && data.companyAddress!.trim().isNotEmpty) {
      for (final line in wordWrap(data.companyAddress!.trim(), width)) {
        buffer.writeln(centerAddress(line));
      }
    }

    if (data.companyCity != null && data.companyCity!.trim().isNotEmpty) {
      buffer.writeln(centerAddress(data.companyCity!.trim()));
    }

    if (data.companyPhone != null && data.companyPhone!.trim().isNotEmpty) {
      buffer.writeln(centerAddress('Phone: ${data.companyPhone!.trim()}'));
    }

    if (data.companyGstin != null && data.companyGstin!.trim().isNotEmpty) {
      buffer.writeln(centerAddress('GSTIN: ${data.companyGstin!.trim()}'));
    }

    buffer.writeln(divider('-'));

    // 2. Title & Metadata
    if (data.title.isNotEmpty) {
      buffer.writeln(centerBold('*** ${data.title.toUpperCase()} ***'));
    }

    buffer.writeln(boldLeft('Name:  ${data.customerName}'));
    buffer.writeln(boldLeft('Bill No:  ${data.invoiceNumber}'));
    buffer.writeln('L:Date:     ${data.invoiceDate}');

    if (data.customerPhone != null && data.customerPhone!.trim().isNotEmpty && data.customerPhone!.trim() != '-') {
      buffer.writeln('L:Phone:    ${data.customerPhone!.trim()}');
    }

    buffer.writeln(divider('-'));

    // 3. Item Table Header
    buffer.writeln(formatRowThree('ITEM NAME', 'QTY', 'AMOUNT'));
    buffer.writeln(divider('-'));

    // 4. Line Items
    if (data.items.isEmpty) {
      buffer.writeln(formatRowThree('Standard Service', 'x1', data.subtotal.toStringAsFixed(2)));
    } else {
      for (final item in data.items) {
        final String qtyFormatted = item.quantity.truncateToDouble() == item.quantity
            ? 'x${item.quantity.toInt()}'
            : 'x${item.quantity.toStringAsFixed(2)}';

        final String fullItemDesc = (item.jobName != null && item.jobName!.trim().isNotEmpty)
            ? '${item.description} (${item.jobName!.trim()})'
            : item.description;

        final itemLines = formatRowThreeLines(
          fullItemDesc,
          qtyFormatted,
          item.amount.toStringAsFixed(2),
        );
        for (final l in itemLines) {
          buffer.writeln(l);
        }
      }
    }

    buffer.writeln(divider('-'));

    // 5. Totals
    buffer.writeln(formatRowTwo('Subtotal', 'Rs.${data.subtotal.toStringAsFixed(2)}'));

    if (data.cgstAmount > 0 || data.sgstAmount > 0) {
      final double halfPct = data.taxPercentage > 0 ? (data.taxPercentage / 2) : 9.0;
      final String halfPctStr = halfPct.truncateToDouble() == halfPct ? halfPct.toInt().toString() : halfPct.toStringAsFixed(1);
      if (data.cgstAmount > 0) {
        buffer.writeln(formatRowTwo('CGST ($halfPctStr%)', 'Rs.${data.cgstAmount.toStringAsFixed(2)}'));
      }
      if (data.sgstAmount > 0) {
        buffer.writeln(formatRowTwo('SGST ($halfPctStr%)', 'Rs.${data.sgstAmount.toStringAsFixed(2)}'));
      }
    } else if (data.igstAmount > 0) {
      final String pctStr = data.taxPercentage > 0 ? '${data.taxPercentage.toInt()}%' : '18%';
      buffer.writeln(formatRowTwo('IGST ($pctStr)', 'Rs.${data.igstAmount.toStringAsFixed(2)}'));
    } else if (data.taxAmount > 0) {
      final taxLabel = data.taxName != null && data.taxName!.isNotEmpty
          ? (data.taxPercentage > 0 ? '${data.taxName} (${data.taxPercentage.toStringAsFixed(0)}%)' : data.taxName!)
          : 'GST';
      buffer.writeln(formatRowTwo(taxLabel, 'Rs.${data.taxAmount.toStringAsFixed(2)}'));
    }

    if (data.roundOff.abs() > 0.001) {
      final sign = data.roundOff > 0 ? '+' : '';
      buffer.writeln(formatRowTwo('Round Off', '$sign${data.roundOff.toStringAsFixed(2)}'));
    }

    buffer.writeln(divider('='));
    buffer.writeln(formatRowTwoBold('GRAND TOTAL', 'Rs.${data.grandTotal.toStringAsFixed(2)}'));
    buffer.writeln(divider('='));

    // 6. Notes (if any)
    if (data.notes != null && data.notes!.trim().isNotEmpty) {
      buffer.writeln('L:Note: ${data.notes!.trim()}');
      buffer.writeln(divider('-'));
    }

    // 7. Footer
    buffer.writeln('L:');
    buffer.writeln(center('Thank you Visit Again!'));
    buffer.writeln(center('Roots Digital Press Billing System'));

    return buffer.toString();
  }

  /// Generates a test print ticket matching NeuGen test print
  static String generateTestReceipt(String companyName) {
    final buffer = StringBuffer();
    buffer.writeln(doubleBoldCenter(companyName.toUpperCase()));
    buffer.writeln(divider('-'));
    buffer.writeln('L:');
    buffer.writeln(centerBold('3-INCH THERMAL PRINTER TEST'));
    buffer.writeln(center('Raster Canvas Engine (576 Dots / 203 DPI)'));
    buffer.writeln(center('Direct Silent Backend Relay Connected!'));
    buffer.writeln('L:');
    buffer.writeln('L:Date/Time   : ${DateTime.now().toLocal().toString().substring(0, 19)}');
    buffer.writeln('L:Paper Width : 80mm / 3-inch');
    buffer.writeln('L:Font Engine : Monospace / RobotoMono');
    buffer.writeln(divider('-'));
    buffer.writeln(formatRowThree('DIAGNOSTICS ITEM', 'QTY', 'STATUS'));
    buffer.writeln(divider('-'));
    buffer.writeln(formatRowThree('ESC/POS Head 203 DPI', 'x1', 'PASS'));
    buffer.writeln(formatRowThree('Raster Stream Relay', 'x1', 'PASS'));
    buffer.writeln(formatRowThree('Typography Hierarchy', 'x1', 'PASS'));
    buffer.writeln(divider('='));
    buffer.writeln(formatRowTwoBold('TEST RESULT', 'VERIFIED OK'));
    buffer.writeln(divider('='));
    buffer.writeln('L:');
    buffer.writeln(center('*** TEST COMPLETED ***'));
    buffer.writeln(center('Roots Digital Press'));
    return buffer.toString();
  }

  /// Strips line tags for clean UI preview
  static String cleanForPreview(String rawText) {
    final lines = rawText.split('\n');
    final cleaned = lines.map((line) {
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);
      if (line.startsWith('DBC:')) return line.substring(4);
      if (line.startsWith('DB:')) return line.substring(3);
      if (line.startsWith('CB:')) return line.substring(3);
      if (line.startsWith('CA:')) return line.substring(3);
      if (line.startsWith('BC:')) return line.substring(3);
      if (line.startsWith('C:')) return line.substring(2);
      if (line.startsWith('B:')) return line.substring(2);
      if (line.startsWith('L:')) return line.substring(2);
      if (line.startsWith('D:')) {
        if (line.length > 2) {
          final char = line.substring(2, 3);
          return char * width;
        }
        return '';
      }
      return line;
    }).toList();
    return cleaned.join('\n');
  }
}
