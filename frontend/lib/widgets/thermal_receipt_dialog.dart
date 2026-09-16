// CHANGE-2026-09-08: Created Thermal Receipt Preview and Print Dialog Widget.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/sales_bill_model.dart';
import '../models/job_model.dart';
import '../providers/company_provider.dart';
import '../services/printer_service.dart';
import '../services/api_service.dart';
import '../core/constants/api_endpoints.dart';

class ThermalReceiptDialog extends StatefulWidget {
  final ReceiptPrintData receiptData;

  const ThermalReceiptDialog({
    super.key,
    required this.receiptData,
  });

  /// Opens receipt preview and print dialog for a normal Sales Bill
  static Future<void> showForSalesBill(BuildContext context, SalesBillModel bill) async {
    final company = context.read<CompanyProvider>().company;

    SalesBillModel fullBill = bill;
    if ((fullBill.items.isEmpty || fullBill.taxPercentage == 0) && fullBill.id != null) {
      try {
        final api = ApiService();
        final resp = await api.get('${ApiEndpoints.salesBills}/${fullBill.id}');
        if (resp.success && resp.data != null) {
          fullBill = SalesBillModel.fromJson(resp.data);
        }
      } catch (e) {
        debugPrint('Error fetching full sales bill details for print: $e');
      }
    }

    final totalTax = fullBill.totalTaxAmount;

    final receiptData = ReceiptPrintData(
      companyName: company?.companyName ?? 'ROOTS DIGITAL PRESS',
      companyAddress: company?.address,
      companyCity: [company?.city, company?.state].where((s) => s != null && s.isNotEmpty).join(', '),
      companyPhone: company?.phone,
      companyGstin: company?.gstin,
      title: 'TAX INVOICE',
      invoiceNumber: fullBill.billNumber ?? 'INV-NEW',
      invoiceDate: Formatters.formatDate(fullBill.billDate),
      customerName: fullBill.customerName ?? 'Walk-in Customer',
      customerPhone: fullBill.customerPhone,
      items: fullBill.items.map((i) {
        final paper = (i.paperNameSnapshot ?? '').trim();
        final job = (i.jobName ?? '').trim();
        final printout = (i.printoutTypeNameSnapshot ?? '').trim();

        String desc = paper;
        if (job.isNotEmpty) {
          desc = desc.isNotEmpty ? '$desc - $job' : job;
        }
        if (printout.isNotEmpty) {
          desc = desc.isNotEmpty ? '$desc ($printout)' : printout;
        }
        if (desc.isEmpty) desc = 'Printout Service';

        final rate = i.quantity > 0 ? (i.calculatedAmount / i.quantity) : 0.0;
        return ReceiptLineItem(
          description: desc,
          jobName: i.jobName,
          quantity: i.quantity,
          rate: rate,
          amount: i.calculatedAmount,
        );
      }).toList(),
      subtotal: fullBill.subtotal,
      taxName: fullBill.taxName ?? 'GST',
      taxPercentage: fullBill.taxPercentage,
      taxAmount: totalTax,
      cgstAmount: fullBill.cgstAmount,
      sgstAmount: fullBill.sgstAmount,
      igstAmount: fullBill.igstAmount,
      roundOff: fullBill.roundOff,
      grandTotal: fullBill.grandTotal,
      notes: fullBill.notes,
    );

    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => ThermalReceiptDialog(receiptData: receiptData),
      );
    }
  }

  /// Opens receipt preview and print dialog for an Estimate / Job Customer
  static Future<void> showForJob(BuildContext context, JobModel job) async {
    final company = context.read<CompanyProvider>().company;

    // If job was selected from table, job.items might not have been loaded. Fetch full details:
    List<JobItemModel> jobItems = job.items;
    if (jobItems.isEmpty && job.id != null) {
      try {
        final api = ApiService();
        final resp = await api.get('${ApiEndpoints.jobs}/${job.id}');
        if (resp.success && resp.data != null && resp.data['items'] is List) {
          final List rawItems = resp.data['items'];
          jobItems = rawItems.map((i) => JobItemModel.fromJson(i)).toList();
        }
      } catch (e) {
        debugPrint('Error fetching full job items for print: $e');
      }
    }

    final receiptData = ReceiptPrintData(
      companyName: company?.companyName ?? 'ROOTS DIGITAL PRESS',
      companyAddress: company?.address,
      companyCity: [company?.city, company?.state].where((s) => s != null && s.isNotEmpty).join(', '),
      companyPhone: company?.phone,
      companyGstin: company?.gstin,
      title: 'JOB ESTIMATE',
      invoiceNumber: job.jobNumber ?? 'JOB-NEW',
      invoiceDate: Formatters.formatDate(job.jobDate),
      customerName: job.customerName ?? 'Estimate Customer',
      customerPhone: job.customerPhone,
      items: jobItems.map((i) {
        final paper = i.paperNameSnapshot.trim();
        final job = (i.jobName ?? '').trim();
        final printout = i.printoutTypeNameSnapshot.trim();

        String desc = paper;
        if (job.isNotEmpty) {
          desc = desc.isNotEmpty ? '$desc - $job' : job;
        }
        if (printout.isNotEmpty) {
          desc = desc.isNotEmpty ? '$desc ($printout)' : printout;
        }
        if (desc.isEmpty) desc = 'Estimate Printout Item';

        final rate = i.quantity > 0 ? (i.calculatedAmount / i.quantity) : 0.0;
        return ReceiptLineItem(
          description: desc,
          jobName: i.jobName,
          quantity: i.quantity,
          rate: rate,
          amount: i.calculatedAmount,
        );
      }).toList(),
      subtotal: job.subtotal,
      taxName: null,
      taxAmount: 0.0,
      roundOff: 0.0,
      grandTotal: job.grandTotal,
      notes: job.notes,
    );

    if (context.mounted) {
      await showDialog(
        context: context,
        builder: (_) => ThermalReceiptDialog(receiptData: receiptData),
      );
    }
  }

  @override
  State<ThermalReceiptDialog> createState() => _ThermalReceiptDialogState();
}

class _ThermalReceiptDialogState extends State<ThermalReceiptDialog> {
  bool _isPrinting = false;

  Future<void> _handleThermalPrint() async {
    setState(() => _isPrinting = true);
    try {
      await PrinterService.printReceipt(widget.receiptData);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt sent to thermal printer successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.print_disabled, color: AppColors.error),
                SizedBox(width: 8),
                Text('Print Failed'),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.receiptData;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF1F5F9),
      child: Container(
        width: 480,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                const Text('3-Inch Thermal Receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 3-Inch Format Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.print_outlined, color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '3-Inch (80mm) Thermal Roll Layout — Crisp System Printing',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Paper Receipt Preview (White card with dashed borders, monospace font)
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Text(
                        data.companyName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'monospace', color: Colors.black),
                      ),
                      if (data.companyAddress != null)
                        Text(data.companyAddress!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.black87)),
                      if (data.companyCity != null && data.companyCity!.isNotEmpty)
                        Text(data.companyCity!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.black87)),
                      if (data.companyPhone != null)
                        Text('Phone: ${data.companyPhone}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 9.5, fontFamily: 'monospace', color: Colors.black87)),
                      if (data.companyGstin != null && data.companyGstin!.isNotEmpty)
                        Text('GSTIN: ${data.companyGstin}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10.0, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.black)),

                      const SizedBox(height: 6),
                      const Divider(color: Colors.black, thickness: 1.5),
                      const SizedBox(height: 2),

                      // Title
                      Text('*** ${data.title} ***', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const SizedBox(height: 6),

                      // Meta
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Name:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          Text(data.customerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Bill No:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          Text(data.invoiceNumber, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Date:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          Text(data.invoiceDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ],
                      ),
                      if (data.customerPhone != null && data.customerPhone!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Phone:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            Text(data.customerPhone!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                      ],

                      const SizedBox(height: 6),
                      const Divider(color: Colors.black, thickness: 1.0),

                      // Items Table Header (ITEM, QTY, Amount)
                      const Row(
                        children: [
                          Expanded(flex: 6, child: Text('ITEM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                          Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                          Expanded(flex: 4, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'))),
                        ],
                      ),
                      const Divider(color: Colors.black, thickness: 1.0),

                      // Line Items
                      ...data.items.map((item) {
                        final String qtyFormatted = item.quantity.truncateToDouble() == item.quantity
                            ? 'x${item.quantity.toInt()}'
                            : 'x${item.quantity.toStringAsFixed(2)}';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Text(
                                  item.description,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace', color: Colors.black),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  qtyFormatted,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(
                                  item.amount.toStringAsFixed(2),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 6),
                      const Divider(color: Colors.black, thickness: 1.0),

                      // Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          Text('Rs.${data.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ],
                      ),
                      if (data.cgstAmount > 0 || data.sgstAmount > 0) ...[
                        if (data.cgstAmount > 0) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('CGST (${(data.taxPercentage / 2).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              Text('Rs.${data.cgstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                        if (data.sgstAmount > 0) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('SGST (${(data.taxPercentage / 2).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                              Text('Rs.${data.sgstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ] else if (data.igstAmount > 0) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('IGST (${data.taxPercentage > 0 ? data.taxPercentage.toInt() : 18}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            Text('Rs.${data.igstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                      ] else if (data.taxAmount > 0) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${data.taxName ?? "GST"}${data.taxPercentage > 0 ? " (${data.taxPercentage.toInt()}%)" : ""}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            Text('Rs.${data.taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                      ],
                      if (data.roundOff.abs() > 0.001) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Round Off', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                            Text('${data.roundOff > 0 ? "+" : ""}${data.roundOff.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                      ],

                      const SizedBox(height: 6),
                      const Divider(color: Colors.black, thickness: 2.0),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GRAND TOTAL', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                          Text('Rs.${data.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                        ],
                      ),
                      const Divider(color: Colors.black, thickness: 2.0),

                      if (data.notes != null && data.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('Note: ${data.notes!}', style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, fontFamily: 'monospace')),
                      ],

                      const SizedBox(height: 12),
                      const Text('Thank you Visit Again!', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const Text('Roots Digital Press Billing System', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.black54, fontFamily: 'monospace')),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: _isPrinting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.print, size: 20),
                    label: Text(_isPrinting ? 'Preparing Print...' : 'Print Thermal Receipt (3-inch)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isPrinting ? null : _handleThermalPrint,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
