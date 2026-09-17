// CHANGE-2026-09-08: NeuGen POS Architecture Thermal Printing Service.
// Draws receipt canvas with exact 80mm (576px / 203 DPI) typography, bold weights,
// monospaced font hierarchy, and equal top/bottom margins, rasterizing to ESC/POS bytes.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'api_service.dart';
import 'receipt_generator.dart';
import '../core/constants/api_endpoints.dart';
import '../models/printer_settings_model.dart';

class ReceiptLineItem {
  final String description;
  final String? jobName;
  final double quantity;
  final double rate;
  final double amount;

  const ReceiptLineItem({
    required this.description,
    this.jobName,
    required this.quantity,
    required this.rate,
    required this.amount,
  });
}

class ReceiptPrintData {
  final String companyName;
  final String? companyAddress;
  final String? companyCity;
  final String? companyPhone;
  final String? companyGstin;
  final String title; // e.g. "TAX INVOICE" or "JOB ESTIMATE"
  final String invoiceNumber;
  final String invoiceDate;
  final String customerName;
  final String? customerPhone;
  final String? jobName;
  final List<ReceiptLineItem> items;
  final double subtotal;
  final String? taxName;
  final double taxPercentage;
  final double taxAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double roundOff;
  final double grandTotal;
  final String? notes;

  const ReceiptPrintData({
    required this.companyName,
    this.companyAddress,
    this.companyCity,
    this.companyPhone,
    this.companyGstin,
    required this.title,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.customerName,
    this.customerPhone,
    this.jobName,
    required this.items,
    required this.subtotal,
    this.taxName,
    this.taxPercentage = 0.0,
    this.taxAmount = 0.0,
    this.cgstAmount = 0.0,
    this.sgstAmount = 0.0,
    this.igstAmount = 0.0,
    this.roundOff = 0.0,
    required this.grandTotal,
    this.notes,
  });
}

class PrinterService {
  /// Standard 80 mm / 3-inch thermal head resolution (standard 203 DPI = 576 dots per line).
  static const double canvasWidth = 576.0;
  static const double margin = 24.0;
  static const double usableWidth = canvasWidth - margin * 2; // 528.0

  /// Helper to create configured TextPainter for crisp thermal receipt typography matching NeuGen POS
  static TextPainter _makePainter(
    String text,
    double size,
    FontWeight weight, {
    TextAlign align = TextAlign.left,
    Color color = const Color(0xFF000000),
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontFamilyFallback: const ['Roboto', 'Arial', 'sans-serif'],
          fontSize: size,
          fontWeight: weight,
          color: color,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    );
  }

  /// Exact NeuGen POS Canvas drawing engine.
  /// Interprets tagged text lines (DBC:, CB:, C:, B:, L:, BC:, D:)
  /// and renders crisp monochrome raster imagery onto an in-memory 576px Canvas.
  static Future<ui.Image> drawTextToReceiptImage(String rawText) async {
    // Col width configurations (matches NeuGen POS fractions)
    final double itemColW = usableWidth * 0.42;
    final double qtyColW = usableWidth * 0.14;
    final double rateColW = usableWidth * 0.20;
    final double totalColW = usableWidth * 0.24;

    final double itemColX = margin;
    final double qtyColX = itemColX + itemColW;
    final double rateColX = qtyColX + qtyColW;
    final double totalColX = rateColX + rateColW;

    final List<void Function(Canvas)> drawOps = [];
    // NeuGen balanced top margin: 24.0px
    double y = 24.0;

    final List<String> rawLines = rawText.split('\n');
    for (String line in rawLines) {
      if (line.endsWith('\r')) line = line.substring(0, line.length - 1);

      if (line.isEmpty) {
        y += 20.0;
        continue;
      }

      String tag;
      String content;

      if (line.startsWith('DBC:')) {
        tag = 'DBC'; content = line.substring(4);
      } else if (line.startsWith('DB:')) {
        tag = 'DB'; content = line.substring(3);
      } else if (line.startsWith('CB:')) {
        tag = 'CB'; content = line.substring(3);
      } else if (line.startsWith('CA:')) {
        tag = 'CA'; content = line.substring(3);
      } else if (line.startsWith('BC:')) {
        tag = 'BC'; content = line.substring(3);
      } else if (line.startsWith('C:')) {
        tag = 'C';  content = line.substring(2);
      } else if (line.startsWith('B:')) {
        tag = 'B';  content = line.substring(2);
      } else if (line.startsWith('D:')) {
        tag = 'D';  content = line.substring(2);
      } else if (line.startsWith('L:')) {
        tag = 'L';  content = line.substring(2);
      } else {
        tag = 'L';  content = line;
      }

      if (content.isEmpty) {
        y += 20.0;
        continue;
      }

      if (tag == 'D') {
        // Divider line (clean single or bold double)
        final double lineY = y + 6.0;
        drawOps.add((canvas) {
          final paint = Paint()
            ..color = const Color(0xFF000000)
            ..strokeWidth = content.contains('=') ? 1.8 : 1.2;
          canvas.drawLine(
            Offset(margin, lineY),
            Offset(canvasWidth - margin, lineY),
            paint,
          );
        });
        y += 18.0;
      } else if (tag == 'BC' && (content.contains('Rs.') || content.contains('GRAND TOTAL') || content.contains('TEST RESULT'))) {
        // Bold two-column row (Grand Total / Highlighted result)
        final parts = content.split('  ');
        final cleanParts = parts.where((p) => p.trim().isNotEmpty).toList();
        final label = cleanParts.isNotEmpty ? cleanParts.first.trim() : '';
        final val = cleanParts.length > 1 ? cleanParts.last.trim() : '';

        final labelTp = _makePainter(label, 30.0, FontWeight.w900)..layout(maxWidth: usableWidth * 0.55);
        final valTp = _makePainter(val, 30.0, FontWeight.w900, align: TextAlign.right)..layout(maxWidth: usableWidth * 0.45);
        final double rowH = labelTp.height > valTp.height ? labelTp.height : valTp.height;
        final double drawY = y;

        drawOps.add((canvas) {
          labelTp.paint(canvas, Offset(margin, drawY));
          valTp.paint(canvas, Offset(canvasWidth - margin - valTp.width, drawY));
        });
        y += rowH + 6.0;
      } else if (tag == 'L' && (content.contains('Rs.') || content.contains('Round Off'))) {
        // Normal two-column summary row (Subtotal, Tax, Round off)
        final parts = content.split('  ');
        final cleanParts = parts.where((p) => p.trim().isNotEmpty).toList();
        final label = cleanParts.isNotEmpty ? cleanParts.first.trim() : '';
        final val = cleanParts.length > 1 ? cleanParts.last.trim() : '';

        final labelTp = _makePainter(label, 26.0, FontWeight.bold)..layout(maxWidth: usableWidth * 0.55);
        final valTp = _makePainter(val, 26.0, FontWeight.bold, align: TextAlign.right)..layout(maxWidth: usableWidth * 0.45);
        final double rowH = labelTp.height > valTp.height ? labelTp.height : valTp.height;
        final double drawY = y;

        drawOps.add((canvas) {
          labelTp.paint(canvas, Offset(margin, drawY));
          valTp.paint(canvas, Offset(canvasWidth - margin - valTp.width, drawY));
        });
        y += rowH + 6.0;
      } else if ((tag == 'L' || tag == 'B') &&
          content.contains(':') &&
          (content.contains('Name:') ||
           content.contains('Job Name:') ||
           content.contains('Bill No:') ||
           content.contains('Date:') ||
           content.contains('Time:') ||
           content.contains('Phone:') ||
           content.contains('Printer IP:') ||
           content.contains('Date/Time:') ||
           content.contains('Paper Width:') ||
           content.contains('Font Engine:'))) {
        // Meta two-column detail row (Name, Bill No, Date, Time, Phone, etc.)
        final int colonIndex = content.indexOf(':');
        final label = '${content.substring(0, colonIndex).trim()}:';
        final val = content.substring(colonIndex + 1).trim();

        final labelTp = _makePainter(label, 26.0, FontWeight.bold)..layout(maxWidth: usableWidth * 0.45);
        final valTp = _makePainter(val, 26.0, FontWeight.bold, align: TextAlign.right)..layout(maxWidth: usableWidth * 0.55);
        final double rowH = labelTp.height > valTp.height ? labelTp.height : valTp.height;
        final double drawY = y;

        drawOps.add((canvas) {
          labelTp.paint(canvas, Offset(margin, drawY));
          valTp.paint(canvas, Offset(canvasWidth - margin - valTp.width, drawY));
        });
        y += rowH + 6.0;
      } else if ((tag == 'L' || tag == 'B') &&
          (content.startsWith('ITEM NAME') ||
           content.startsWith('ITEM') ||
           content.startsWith('DIAGNOSTICS ITEM') ||
           (content.length >= 36 &&
            (content.contains(' x') ||
             content.contains('x1') ||
             content.contains('x2') ||
             content.contains('x3') ||
             content.contains('x4') ||
             content.contains('x5') ||
             content.contains('x6') ||
             content.contains('x7') ||
             content.contains('x8') ||
             content.contains('x9') ||
             content.contains('x0') ||
             content.contains('PASS'))))) {
        // Item table row (3 columns matching ReceiptGenerator width)
        String name = '';
        String qty = '';
        String price = '';

        if (content.length >= 47) {
          name = content.substring(0, 27).trim();
          qty = content.substring(27, 33).trim();
          price = content.substring(33, 47).trim();
        } else {
          final parts = content.split('  ').where((p) => p.isNotEmpty).toList();
          name = parts.isNotEmpty ? parts.first.trim() : '';
          qty = parts.length > 1 ? parts[1].trim() : '';
          price = parts.length > 2 ? parts[2].trim() : '';
        }

        if (name == 'ITEM NAME' && qty == 'QTY') {
          name = 'ITEM';
          qty = 'QTY';
          price = 'Amount';
        }

        final isHeader = (name == 'ITEM' || name == 'ITEM NAME' || name == 'DIAGNOSTICS ITEM') && (qty == 'QTY');
        final double size = isHeader ? 22.0 : 26.0;
        final FontWeight weight = FontWeight.bold;

        final nameTp = _makePainter(name, size, weight)..layout(maxWidth: itemColW - 8);
        final qtyTp = _makePainter(qty, size, weight, align: TextAlign.center)..layout(maxWidth: qtyColW);
        final priceTp = _makePainter(price, size, weight, align: TextAlign.right)..layout(maxWidth: totalColW);

        final double rowH = [nameTp.height, qtyTp.height, priceTp.height].reduce((a, b) => a > b ? a : b);
        final double drawY = y;

        drawOps.add((canvas) {
          nameTp.paint(canvas, Offset(itemColX, drawY));
          qtyTp.paint(canvas, Offset(qtyColX + (qtyColW - qtyTp.width) / 2, drawY));
          priceTp.paint(canvas, Offset(totalColX + totalColW - priceTp.width, drawY));
        });
        y += rowH + 6.0;
      } else if (tag == 'CA') {
        // Centered address / contact details (reduced to 21pt for crisp hierarchy)
        final cleanText = content.trim();
        final tp = _makePainter(cleanText, 21.0, FontWeight.w600, align: TextAlign.center)
          ..layout(maxWidth: usableWidth);

        final double drawY = y;
        final double drawX = (canvasWidth - tp.width) / 2;

        drawOps.add((canvas) => tp.paint(canvas, Offset(drawX, drawY)));
        y += tp.height + 4.0;
      } else {
        // Standard text lines (centered or left-aligned)
        final bool isCenter = tag == 'C' || tag == 'CB' || tag == 'DBC';
        final bool isBold = tag == 'B' || tag == 'CB' || tag == 'DB' || tag == 'DBC' || tag == 'BC';
        final double size = (tag == 'DB' || tag == 'DBC') ? 34.0 : 26.0;

        FontWeight weight = FontWeight.normal;
        if (tag == 'DBC') {
          weight = FontWeight.w900;
        } else if (tag == 'CB') {
          weight = FontWeight.w700;
        } else if (isBold) {
          weight = FontWeight.bold;
        }

        final cleanText = content.trim();
        final tp = _makePainter(cleanText, size, weight, align: isCenter ? TextAlign.center : TextAlign.left)
          ..layout(maxWidth: usableWidth);

        final double drawY = y;
        final double drawX = isCenter ? (canvasWidth - tp.width) / 2 : margin;

        drawOps.add((canvas) => tp.paint(canvas, Offset(drawX, drawY)));
        y += tp.height + 6.0;
      }
    }

    // NeuGen balanced bottom margin: 24.0px
    final double totalHeight = y + 24.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Pure white crisp background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasWidth, totalHeight),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    for (final op in drawOps) {
      op(canvas);
    }

    final picture = recorder.endRecording();
    return await picture.toImage(canvasWidth.toInt(), totalHeight.toInt());
  }

  /// Renders structured ReceiptPrintData onto the 576px canvas via ReceiptGenerator
  static Future<ui.Image> renderReceiptToImage(ReceiptPrintData data) async {
    final taggedText = ReceiptGenerator.generateReceipt(data);
    return await drawTextToReceiptImage(taggedText);
  }

  /// Converts rendered ui.Image to img.Image
  static Future<img.Image> convertUiImageToImgImage(ui.Image uiImage) async {
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) throw Exception('Failed to convert canvas image to raw RGBA byte data');

    final buffer = byteData.buffer.asUint8List();
    return img.Image.fromBytes(
      width: uiImage.width,
      height: uiImage.height,
      bytes: buffer.buffer,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );
  }

  /// Converts img.Image to ESC/POS raster byte commands using 'esc_pos_utils_plus'
  /// NeuGen uses feedLines = 1 for perfectly balanced physical paper margins.
  static Future<List<int>> generateEscPosRasterBytes(img.Image image, {int feedLines = 1}) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.imageRaster(image);
    bytes += generator.feed(feedLines);
    bytes += generator.cut();

    return bytes;
  }

  /// Prints raw tagged receipt text directly to the thermal printer
  static Future<void> printReceiptText(String text, {int feedLines = 1, String? invoiceNumber, String? printerName}) async {
    // 1. Draw canvas layout at 576px (80mm standard width)
    final uiImage = await drawTextToReceiptImage(text);

    // 2. Convert to 'image' package Image
    final imgImage = await convertUiImageToImgImage(uiImage);

    // 3. Generate raw ESC/POS raster byte stream
    final escPosBytes = await generateEscPosRasterBytes(imgImage, feedLines: feedLines);

    // 4. Primary path for Web/Desktop: Send to Backend Relay for silent, direct thermal printing
    try {
      final base64Data = base64Encode(escPosBytes);
      final api = ApiService();
      final response = await api.post(ApiEndpoints.printReceipt, {
        'bytes_base64': base64Data,
      });

      if (response.success) {
        debugPrint('[PrinterService] Print job sent successfully via backend relay.');
        return;
      } else {
        debugPrint('[PrinterService] Backend relay returned error: ${response.message}');
        if (response.message.contains('DISABLED') || response.message.contains('not configured')) {
          throw response.message;
        }
      }
    } catch (e) {
      debugPrint('[PrinterService] Relay attempt failed: $e');
      if (e is String && (e.contains('DISABLED') || e.contains('not configured'))) {
        rethrow;
      }
    }

    // 5. Fallback path (Desktop native Printing or OS Dialog)
    final pngBytes = Uint8List.fromList(img.encodePng(imgImage));
    final doc = pw.Document();
    final pdfImage = pw.MemoryImage(pngBytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(pdfImage, fit: pw.BoxFit.fitWidth),
          );
        },
      ),
    );

    final pdfBytes = await doc.save();
    final docName = invoiceNumber != null ? 'Receipt_$invoiceNumber' : 'Thermal_Receipt';

    try {
      final printers = await Printing.listPrinters();
      if (printers.isNotEmpty) {
        final targetPrinter = (printerName != null && printerName.isNotEmpty)
            ? printers.firstWhere(
                (p) => p.name.toLowerCase().contains(printerName.toLowerCase()),
                orElse: () => printers.firstWhere((p) => p.isDefault, orElse: () => printers.first),
              )
            : printers.firstWhere(
                (p) =>
                    p.name.toLowerCase().contains('pos') ||
                    p.name.toLowerCase().contains('thermal') ||
                    p.name.toLowerCase().contains('receipt') ||
                    p.name.toLowerCase().contains('80') ||
                    p.name.toLowerCase().contains('rp') ||
                    p.name.toLowerCase().contains('xp'),
                orElse: () => printers.firstWhere((p) => p.isDefault, orElse: () => printers.first),
              );

        await Printing.directPrintPdf(
          printer: targetPrinter,
          onLayout: (format) async => pdfBytes,
          name: docName,
          format: PdfPageFormat.roll80,
        );
        return;
      }
    } catch (e) {
      debugPrint('Direct printing exception, falling back to layoutPdf: $e');
    }

    await Printing.layoutPdf(
      onLayout: (format) async => pdfBytes,
      name: '$docName.pdf',
      format: PdfPageFormat.roll80,
    );
  }


  /// Connects to printer IP and Port, transmitting raw ESC/POS raster bytes.
  /// On Web, automatically relays through backend since browsers cannot open raw TCP sockets.
  /// On Desktop, connects directly via TCP socket with backend relay fallback.
  static Future<void> sendToTcpPrinter(String ip, int port, List<int> bytes) async {
    if (kIsWeb) {
      final api = ApiService();
      final response = await api.post(ApiEndpoints.printReceipt, {
        'bytes_base64': base64Encode(bytes),
      });
      if (!response.success) {
        throw Exception(response.message);
      }
      return;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
    } on SocketException catch (e) {
      // Direct desktop socket failed, try backend relay
      try {
        final api = ApiService();
        final response = await api.post(ApiEndpoints.printReceipt, {
          'bytes_base64': base64Encode(bytes),
        });
        if (response.success) return;
      } catch (_) {}
      throw Exception('Could not connect to thermal printer at $ip:$port.\n\nTroubleshooting:\n1. Ensure the printer is ON.\n2. Ensure this device and the printer are on the SAME network.\n3. Verify the printer IP address ($ip).\n4. Check if port is $port.\n\n(Network error: ${e.message})');
    } catch (e) {
      // In case of UnsupportedError (e.g. web environment), relay via backend
      try {
        final api = ApiService();
        final response = await api.post(ApiEndpoints.printReceipt, {
          'bytes_base64': base64Encode(bytes),
        });
        if (response.success) return;
      } catch (_) {}
      throw Exception('Could not connect to thermal printer at $ip:$port. Error: $e');
    } finally {
      await socket?.close();
    }
  }

  /// Retrieves stored printer configuration from API
  static Future<PrinterSettingsModel> _fetchPrinterSettings() async {
    final api = ApiService();
    final response = await api.get<PrinterSettingsModel>(
      ApiEndpoints.printerSettings,
      parser: (json) => PrinterSettingsModel.fromJson(json),
    );
    if (response.success && response.data != null) {
      return response.data!;
    }
    throw Exception('Failed to fetch printer configuration: ${response.message}');
  }

  /// Prints structured ReceiptPrintData directly to the thermal printer via TCP socket (Raster Image)
  static Future<void> printReceipt(ReceiptPrintData data, {String? printerName}) async {
    final settings = await _fetchPrinterSettings();
    if (!settings.printerEnabled) {
      throw Exception('Thermal printer is DISABLED. Please enable printer and configure IP/Port in Printer Settings before printing.');
    }

    final ip = settings.printerIp.trim();
    final port = settings.printerPort;

    if (ip.isEmpty) {
      throw Exception('Printer IP address is not configured. Please save a valid Printer IP in Printer Settings.');
    }

    // 1. Generate tagged receipt text matching NeuGen POS
    final receiptText = ReceiptGenerator.generateReceipt(data);

    // 2. Draw canvas layout at 576px (80mm standard width)
    final uiImage = await drawTextToReceiptImage(receiptText);

    // 3. Convert to 'image' package Image
    final imgImage = await convertUiImageToImgImage(uiImage);

    // 4. Generate raw ESC/POS raster byte stream with feedLines: 1 (exact NeuGen specification)
    final escPosBytes = await generateEscPosRasterBytes(imgImage, feedLines: 1);

    // 5. Send raster bytes directly to TCP thermal printer
    await sendToTcpPrinter(ip, port, escPosBytes);
  }

  /// Sends a test print ticket directly to the thermal printer via TCP socket (Raster Image)
  static Future<void> printTest({String companyName = 'ROOTS DIGITAL PRESS', String? printerName}) async {
    final settings = await _fetchPrinterSettings();
    if (!settings.printerEnabled) {
      throw Exception('Thermal printer is DISABLED. Please enable printer and configure IP/Port in Printer Settings before printing.');
    }

    final ip = settings.printerIp.trim();
    final port = settings.printerPort;

    if (ip.isEmpty) {
      throw Exception('Printer IP address is not configured. Please save a valid Printer IP in Printer Settings.');
    }

    // 1. Generate test receipt tagged text matching NeuGen POS
    final testText = ReceiptGenerator.generateTestReceipt(companyName);

    // 2. Draw canvas layout at 576px (80mm standard width)
    final uiImage = await drawTextToReceiptImage(testText);

    // 3. Convert to 'image' package Image
    final imgImage = await convertUiImageToImgImage(uiImage);

    // 4. Generate raw ESC/POS raster byte stream with feedLines: 1
    final escPosBytes = await generateEscPosRasterBytes(imgImage, feedLines: 1);

    // 5. Send raster bytes directly to TCP thermal printer
    await sendToTcpPrinter(ip, port, escPosBytes);
  }
}
